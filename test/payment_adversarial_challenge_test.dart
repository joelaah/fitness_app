import 'dart:async';
import 'dart:convert';
import 'package:fitness_app/features/payments/bloc/payment_bloc.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    PaymentService.resetMockTransactions();
  });

  group('Challenge 1: Simultaneous Concurrent Requests Deduplication', () {
    test(
      '20 concurrent requests with identical idempotency key to mock HTTP backend returns exactly 1 created and 19 replayed',
      () async {
        final lock = <String, Map<String, dynamic>>{};
        var networkHitCount = 0;

        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            networkHitCount++;
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            final amt = (body['amount'] as num).toDouble();
            final split = PlatformFeeCalculator.calculateSplit(amount: amt);

            // Simulate server-side atomic lock check
            final isReplay = lock.containsKey(key);
            if (!isReplay) {
              lock[key] = {
                'transaction_id': 'tx_concurrent_123',
                'order_id': 'order_concurrent_123',
                'amount': split.amount,
                'platform_fee_amount': split.platformFee,
                'trainer_amount': split.trainerAmount,
              };
            }

            final cached = lock[key]!;
            return http.Response(
              json.encode({
                ...cached,
                'replayed': isReplay,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://pulsefit-test.io',
        );

        const testKey = 'idem-concurrent-test-uuid-0001';
        final futures = List.generate(
          20,
          (_) => service.createOrder(
            trainerId: 'trainer-concurrency-1',
            amount: 2500.0,
            idempotencyKey: testKey,
          ),
        );

        final responses = await Future.wait(futures);

        expect(responses.length, 20);
        expect(networkHitCount, 20);

        // Exactly one created (replayed: false), 19 replayed (replayed: true)
        final createdList = responses.where((r) => !r.replayed).toList();
        final replayedList = responses.where((r) => r.replayed).toList();

        expect(
          createdList.length,
          1,
          reason: 'Exactly 1 request should be treated as original creation',
        );
        expect(
          replayedList.length,
          19,
          reason: 'All remaining concurrent requests should be deduplicated',
        );

        // Verify invariant: all returned order IDs and transaction IDs must match identically
        for (final resp in responses) {
          expect(resp.orderId, 'order_concurrent_123');
          expect(resp.transactionId, 'tx_concurrent_123');
          expect(resp.amount, 2500.0);
          expect(resp.platformFeeAmount, 250.0);
          expect(resp.trainerAmount, 2250.0);
        }
      },
    );

    test(
      '20 concurrent requests with identical idempotency key in offline fallback mode deduplicates properly',
      () async {
        // Service without client pointing to dead endpoint triggers offline fallback
        final service = PaymentService(baseUrl: 'http://127.0.0.1:59999');
        const testKey = 'idem-offline-concurrent-uuid-0002';

        final futures = List.generate(
          20,
          (_) => service.createOrder(
            trainerId: 'trainer-offline-concurrency-1',
            amount: 1800.0,
            idempotencyKey: testKey,
          ),
        );

        final responses = await Future.wait(futures);

        expect(responses.length, 20);
        final createdList = responses.where((r) => !r.replayed).toList();
        final replayedList = responses.where((r) => r.replayed).toList();

        expect(createdList.length, 1);
        expect(replayedList.length, 19);

        final originalOrderId = createdList.first.orderId;
        final originalTxId = createdList.first.transactionId;
        for (final resp in responses) {
          expect(resp.orderId, originalOrderId);
          expect(resp.transactionId, originalTxId);
          expect(resp.amount, 1800.0);
          expect(resp.platformFeeAmount, 180.0);
          expect(resp.trainerAmount, 1620.0);
        }
      },
    );
  });

  group('Challenge 2: Network Failure During Order Creation Followed by Immediate Retry', () {
    test(
      'Transient network error on first order attempt followed by immediate retry with same key',
      () async {
        var callCount = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            callCount++;
            if (callCount == 1) {
              // Simulate network drop / gateway timeout
              throw http.ClientException('Connection reset by peer');
            }
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            final amt = (body['amount'] as num).toDouble();
            final split = PlatformFeeCalculator.calculateSplit(amount: amt);
            return http.Response(
              json.encode({
                'transaction_id': 'tx_retry_network_1',
                'order_id': 'order_retry_network_1',
                'amount': split.amount,
                'platform_fee_amount': split.platformFee,
                'trainer_amount': split.trainerAmount,
                'replayed': false,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://pulsefit-test.io',
        );

        const testKey = 'idem-network-failure-test-0003';

        // First attempt catches network exception and creates offline fallback
        final res1 = await service.createOrder(
          trainerId: 'trainer-net-1',
          amount: 2000.0,
          idempotencyKey: testKey,
        );

        expect(res1.amount, 2000.0);
        expect(res1.replayed, isFalse);

        // Second attempt with restored network retries with exact same key
        final res2 = await service.createOrder(
          trainerId: 'trainer-net-1',
          amount: 2000.0,
          idempotencyKey: testKey,
        );

        expect(callCount, 2);
        expect(res2.amount, 2000.0);
      },
    );
  });

  group('Challenge 3: Payment Failure During Checkout Followed by Retry (Key Preservation)', () {
    test(
      'PaymentBloc preserves explicit idempotencyKey on payment failure and retry',
      () async {
        final seenKeys = <String>[];
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            seenKeys.add(key);
            return http.Response(
              json.encode({
                'transaction_id': 'tx_fail_retry',
                'order_id': 'order_fail_retry',
                'amount': 1000.0,
                'platform_fee_amount': 100.0,
                'trainer_amount': 900.0,
                'replayed': seenKeys.length > 1,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://pulsefit-test.io',
        );
        final bloc = PaymentBloc(paymentService: service);

        // 1. Initial attempt with explicit key
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-f1',
            trainerName: 'Coach Sarah',
            amount: 1000.0,
            idempotencyKey: 'explicit-key-999',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        expect(bloc.activeIdempotencyKey, 'explicit-key-999');

        // 2. Gateway failure happens
        bloc.add(
          const PaymentFailedEvent(
            code: 2,
            message: 'User cancelled or card declined',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentFailure>());
        final failState = bloc.state as PaymentFailure;
        expect(failState.canRetry, isTrue);
        expect(failState.cachedIdempotencyKey, 'explicit-key-999');
        expect(bloc.activeIdempotencyKey, 'explicit-key-999');

        // 3. Retry payment
        bloc.add(const RetryPayment());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        final retryCreated = bloc.state as PaymentOrderCreated;
        expect(retryCreated.idempotencyKey, 'explicit-key-999');
        expect(retryCreated.isReplayed, isTrue);

        expect(seenKeys, ['explicit-key-999', 'explicit-key-999']);
        await bloc.close();
      },
    );

    test(
      'PaymentBloc preserves sessionContextKey idempotencyKey on payment failure and retry (CheckoutBottomSheet flow)',
      () async {
        final seenKeys = <String>[];
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            seenKeys.add(key);
            return http.Response(
              json.encode({
                'transaction_id': 'tx_fail_retry_ctx',
                'order_id': 'order_fail_retry_ctx',
                'amount': 1500.0,
                'platform_fee_amount': 150.0,
                'trainer_amount': 1350.0,
                'replayed': seenKeys.length > 1,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://pulsefit-test.io',
        );
        final bloc = PaymentBloc(paymentService: service);

        // 1. Initial attempt with sessionContextKey
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-f2',
            trainerName: 'Coach Marcus',
            amount: 1500.0,
            sessionContextKey: 'ctx-session-checkout-42',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        final initialKey = bloc.activeIdempotencyKey;
        expect(initialKey, isNotNull);

        // 2. Failure occurs
        bloc.add(
          const PaymentFailedEvent(
            code: 2,
            message: 'Network drop during transaction',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentFailure>());
        expect(bloc.activeIdempotencyKey, initialKey);

        // 3. Retry occurs
        bloc.add(const RetryPayment());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        final retriedState = bloc.state as PaymentOrderCreated;
        expect(retriedState.idempotencyKey, initialKey);
        expect(retriedState.isReplayed, isTrue);

        expect(seenKeys.length, 2);
        expect(seenKeys[0], initialKey);
        expect(seenKeys[1], initialKey);
        await bloc.close();
      },
    );

    test(
      'ADVERSARIAL CHECK: PaymentBloc with default parameters (no explicit idempotencyKey, no sessionContextKey) preserves idempotencyKey on RetryPayment',
      () async {
        final seenKeys = <String>[];
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            seenKeys.add(key);
            return http.Response(
              json.encode({
                'transaction_id': 'tx_default_keys',
                'order_id': 'order_default_keys',
                'amount': 500.0,
                'platform_fee_amount': 50.0,
                'trainer_amount': 450.0,
                'replayed': seenKeys.length > 1,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://pulsefit-test.io',
        );
        final bloc = PaymentBloc(paymentService: service);

        // 1. Initial attempt without explicit key and without sessionContextKey
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-default-test',
            trainerName: 'Coach Default',
            amount: 500.0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        final key1 = bloc.activeIdempotencyKey;
        expect(key1, isNotNull);

        // 2. Failure occurs
        bloc.add(
          const PaymentFailedEvent(
            code: 2,
            message: 'Bank timeout',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentFailure>());
        expect((bloc.state as PaymentFailure).cachedIdempotencyKey, key1);

        // 3. Retry occurs
        bloc.add(const RetryPayment());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<PaymentOrderCreated>());
        final retriedState = bloc.state as PaymentOrderCreated;

        // Check whether key was preserved
        expect(
          retriedState.idempotencyKey,
          key1,
          reason: 'RetryPayment should preserve the active idempotency key even when sessionContextKey was omitted',
        );
        expect(seenKeys.length, 2);
        expect(
          seenKeys[1],
          seenKeys[0],
          reason: 'Both order creation calls must pass the identical idempotency key to prevent double charge',
        );

        await bloc.close();
      },
    );
  });

  group('Challenge 4: Strict RFC 4122 UUID v4 Conformance & Entropy Oracle', () {
    test(
      'Generates 1,000 idempotency keys and verifies strict UUID v4 format, version nibble 4, and variant bits [8,9,a,b]',
      () {
        final service = PaymentService();
        final strictUuidV4Regex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );

        final generatedKeys = <String>{};
        const sampleSize = 1000;

        for (var i = 0; i < sampleSize; i++) {
          final key = service.generateIdempotencyKey();

          // 1. Total length must be exactly 36 chars
          expect(key.length, 36, reason: 'Key $key length must be 36');

          // 2. Strict regex check (version 4 and variant 8,9,a,b)
          expect(
            strictUuidV4Regex.hasMatch(key.toLowerCase()),
            isTrue,
            reason: 'Key $key must adhere to strict RFC 4122 UUID v4',
          );

          // 3. Explicit bit checks
          // Character at index 14 is version: must be '4'
          expect(key[14], '4', reason: 'Version nibble must be 4');

          // Character at index 19 is variant: must be 8, 9, a, or b (binary 10xx)
          final variantChar = key[19].toLowerCase();
          expect(['8', '9', 'a', 'b'].contains(variantChar), isTrue);

          // 4. Uniqueness / collision resistance
          expect(
            generatedKeys.contains(key),
            isFalse,
            reason: 'UUID collision detected: $key already generated',
          );
          generatedKeys.add(key);
        }

        expect(generatedKeys.length, sampleSize);
      },
    );
  });

  group('Challenge 5: BLoC Concurrency & Race Condition Stress Tests', () {
    test(
      'CancelPayment while order creation is in flight cancels active key and ignores late-arriving order',
      () async {
        final completer = Completer<http.Response>();

        final slowClient = MockClient((request) async {
          return completer.future;
        });

        final service = PaymentService(
          client: slowClient,
          baseUrl: 'https://pulsefit-test.io',
        );
        final bloc = PaymentBloc(paymentService: service);

        // 1. Initiate payment (hangs on network completer)
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-race-1',
            trainerName: 'Coach Sarah',
            amount: 1000.0,
            sessionContextKey: 'ctx-race-cancel',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state, isA<PaymentOrderCreating>());
        final keyBeforeCancel = bloc.activeIdempotencyKey;
        expect(keyBeforeCancel, isNotNull);

        // 2. User presses Cancel while in flight
        bloc.add(const CancelPayment(sessionContextKey: 'ctx-race-cancel'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state, const PaymentInitial());
        expect(bloc.activeIdempotencyKey, isNull);

        // 3. Late arriving order response finishes
        completer.complete(
          http.Response(
            json.encode({
              'transaction_id': 'tx_late_arrived',
              'order_id': 'order_late_arrived',
              'amount': 1000.0,
              'platform_fee_amount': 100.0,
              'trainer_amount': 900.0,
              'replayed': false,
            }),
            200,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State check: What state is the bloc in now?
        // If state resurrected to PaymentOrderCreated, that's a concurrency race bug!
        expect(
          bloc.state,
          const PaymentInitial(),
          reason: 'A cancelled payment must NOT transition back to PaymentOrderCreated when in-flight request finishes',
        );
        await bloc.close();
      },
    );

    test(
      'Rapid concurrent InitiatePayment double-tap must not create divergent orders or duplicate keys',
      () async {
        final orderKeysCreated = <String>[];
        final slowClient = MockClient((request) async {
          if (request.url.path == '/payments/create-order') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            final body = json.decode(request.body) as Map<String, dynamic>;
            final key = body['idempotency_key'] as String;
            orderKeysCreated.add(key);
            return http.Response(
              json.encode({
                'transaction_id': 'tx_double_tap',
                'order_id': 'order_double_tap',
                'amount': 1000.0,
                'platform_fee_amount': 100.0,
                'trainer_amount': 900.0,
                'replayed': orderKeysCreated.length > 1,
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: slowClient,
          baseUrl: 'https://pulsefit-test.io',
        );
        final bloc = PaymentBloc(paymentService: service);

        // Dispatch 2 InitiatePayment events rapidly (double-tap scenario)
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-double-tap',
            trainerName: 'Coach Sarah',
            amount: 1000.0,
            sessionContextKey: 'session-double-tap',
          ),
        );
        bloc.add(
          const InitiatePayment(
            trainerId: 'trainer-double-tap',
            trainerName: 'Coach Sarah',
            amount: 1000.0,
            sessionContextKey: 'session-double-tap',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Check if both requests shared the same idempotency key or if duplicate orders were spawned
        expect(orderKeysCreated.isNotEmpty, isTrue);
        if (orderKeysCreated.length > 1) {
          expect(
            orderKeysCreated[1],
            orderKeysCreated[0],
            reason: 'If multiple InitiatePayment events are dispatched, they must reuse the active idempotency key for the session',
          );
        }

        await bloc.close();
      },
    );
  });
}

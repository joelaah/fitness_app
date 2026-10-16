import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_app/features/payments/bloc/payment_bloc.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PaymentBloc State Machine Tests', () {
    late PaymentService paymentService;
    final seenKeys = <String>{};

    setUp(() {
      PaymentService.resetMockTransactions();
      seenKeys.clear();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/payments/config') {
          return http.Response(
            json.encode({
              'platform_fee_percentage': 10.0,
              'currency': 'INR',
              'razorpay_key_id': 'rzp_test_mock_123',
            }),
            200,
          );
        }
        if (request.url.path == '/payments/create-order') {
          final body = json.decode(request.body) as Map<String, dynamic>;
          final key = body['idempotency_key'] as String;
          final isReplay = seenKeys.contains(key);
          seenKeys.add(key);

          final amt = (body['amount'] as num).toDouble();
          final split = PlatformFeeCalculator.calculateSplit(amount: amt);
          return http.Response(
            json.encode({
              'transaction_id': 'tx_test_123',
              'order_id': 'order_test_123',
              'amount': split.amount,
              'platform_fee_amount': split.platformFee,
              'trainer_amount': split.trainerAmount,
              'replayed': isReplay,
            }),
            200,
          );
        }
        if (request.url.path == '/payments/verify') {
          return http.Response(
            json.encode({
              'status': 'captured',
              'transaction_id': 'tx_test_123',
            }),
            200,
          );
        }
        if (request.url.path == '/payments/history') {
          return http.Response(
            json.encode({
              'transactions': [
                {
                  'id': 'tx-1',
                  'idempotency_key': 'key-1',
                  'user_id': 'u1',
                  'trainer_id': 't1',
                  'order_id': 'order-1',
                  'amount': 1000.0,
                  'platform_fee': 100.0,
                  'platform_fee_amount': 100.0,
                  'platform_fee_percent': 10.0,
                  'trainer_amount': 900.0,
                  'status': 'captured',
                  'trainer_name': 'Coach Sarah',
                  'created_at': DateTime.now().toIso8601String(),
                },
                {
                  'id': 'tx-2',
                  'idempotency_key': 'key-2',
                  'user_id': 'u1',
                  'trainer_id': 't2',
                  'order_id': 'order-2',
                  'amount': 2000.0,
                  'platform_fee': 200.0,
                  'platform_fee_amount': 200.0,
                  'platform_fee_percent': 10.0,
                  'trainer_amount': 1800.0,
                  'status': 'captured',
                  'trainer_name': 'Coach Mike',
                  'created_at': DateTime.now().toIso8601String(),
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      paymentService = PaymentService(
        client: mockClient,
        baseUrl: 'https://mock.pulsefit.io',
      );
    });

    test('initial state is PaymentInitial', () {
      final bloc = PaymentBloc(paymentService: paymentService);
      expect(bloc.state, const PaymentInitial());
      bloc.close();
    });

    blocTest<PaymentBloc, PaymentState>(
      'emits [PaymentOrderCreating, PaymentOrderCreated] on successful InitiatePayment',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) => bloc.add(const InitiatePayment(
        trainerId: 'trainer-001',
        trainerName: 'Coach Sarah',
        amount: 1500.0,
        idempotencyKey: 'test-key-001',
      )),
      expect: () => [
        isA<PaymentOrderCreating>()
            .having((s) => s.idempotencyKey, 'idempotencyKey', 'test-key-001')
            .having((s) => s.trainerId, 'trainerId', 'trainer-001')
            .having((s) => s.amount, 'amount', 1500.0),
        isA<PaymentOrderCreated>()
            .having((s) => s.idempotencyKey, 'idempotencyKey', 'test-key-001')
            .having((s) => s.isReplayed, 'isReplayed', isFalse)
            .having((s) => s.amount, 'amount', 1500.0),
      ],
      verify: (bloc) {
        expect(bloc.activeIdempotencyKey, 'test-key-001');
        expect(bloc.lastOrderResponse, isNotNull);
      },
    );

    blocTest<PaymentBloc, PaymentState>(
      'replays existing order with replayed=true when same idempotency key is submitted',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) async {
        bloc.add(const InitiatePayment(
          trainerId: 'trainer-001',
          trainerName: 'Coach Sarah',
          amount: 1500.0,
          idempotencyKey: 'replay-key-002',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const InitiatePayment(
          trainerId: 'trainer-001',
          trainerName: 'Coach Sarah',
          amount: 1500.0,
          idempotencyKey: 'replay-key-002',
        ));
      },
      expect: () => [
        isA<PaymentOrderCreating>(),
        isA<PaymentOrderCreated>().having((s) => s.isReplayed, 'isReplayed', isFalse),
        isA<PaymentOrderCreating>(),
        isA<PaymentOrderCreated>().having((s) => s.isReplayed, 'isReplayed', isTrue),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits [PaymentVerifying, PaymentSuccess] on ConfirmPaymentSuccess',
      build: () => PaymentBloc(paymentService: paymentService),
      seed: () => PaymentOrderCreated(
        orderResponse: const PaymentOrderResponse(
          transactionId: 'tx-123',
          orderId: 'order_123',
          amount: 1500.0,
          platformFeeAmount: 150.0,
          trainerAmount: 1350.0,
          replayed: false,
        ),
        idempotencyKey: 'idem-123',
        trainerId: 'trainer-001',
        trainerName: 'Coach Sarah',
        amount: 1500.0,
        isReplayed: false,
      ),
      act: (bloc) => bloc.add(const ConfirmPaymentSuccess(
        orderId: 'order_123',
        paymentId: 'pay_123',
        signature: 'sig_123',
      )),
      expect: () => [
        isA<PaymentVerifying>()
            .having((s) => s.orderId, 'orderId', 'order_123')
            .having((s) => s.paymentId, 'paymentId', 'pay_123'),
        isA<PaymentSuccess>()
            .having((s) => s.transaction.orderId, 'orderId', 'order_123')
            .having((s) => s.transaction.paymentId, 'paymentId', 'pay_123')
            .having((s) => s.transaction.isCaptured, 'isCaptured', isTrue),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'emits PaymentFailure on PaymentFailedEvent and preserves idempotency key',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) async {
        bloc.add(const InitiatePayment(
          trainerId: 'trainer-001',
          trainerName: 'Coach Sarah',
          amount: 1000.0,
          idempotencyKey: 'failed-session-key',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const PaymentFailedEvent(
          code: 2,
          message: 'Payment declined by bank',
        ));
      },
      expect: () => [
        isA<PaymentOrderCreating>(),
        isA<PaymentOrderCreated>(),
        isA<PaymentFailure>()
            .having((s) => s.message, 'message', 'Payment declined by bank')
            .having((s) => s.canRetry, 'canRetry', isTrue)
            .having((s) => s.cachedIdempotencyKey, 'cachedIdempotencyKey', 'failed-session-key'),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'RetryPayment re-invokes initiate with preserved idempotency key',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) async {
        bloc.add(const InitiatePayment(
          trainerId: 'trainer-001',
          trainerName: 'Coach Sarah',
          amount: 1000.0,
          idempotencyKey: 'retry-preserved-key',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const RetryPayment());
      },
      expect: () => [
        isA<PaymentOrderCreating>(),
        isA<PaymentOrderCreated>(),
        isA<PaymentOrderCreating>()
            .having((s) => s.idempotencyKey, 'idempotencyKey', 'retry-preserved-key'),
        isA<PaymentOrderCreated>()
            .having((s) => s.idempotencyKey, 'idempotencyKey', 'retry-preserved-key')
            .having((s) => s.isReplayed, 'isReplayed', isTrue),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'CancelPayment and ResetPayment reset state to PaymentInitial',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) async {
        bloc.add(const InitiatePayment(
          trainerId: 'trainer-001',
          trainerName: 'Coach Sarah',
          amount: 1000.0,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const CancelPayment());
      },
      expect: () => [
        isA<PaymentOrderCreating>(),
        isA<PaymentOrderCreated>(),
        const PaymentInitial(),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'LoadPaymentHistory loads and computes correct totals for user and trainer',
      build: () => PaymentBloc(paymentService: paymentService),
      act: (bloc) => bloc.add(const LoadPaymentHistory(isTrainerMode: true)),
      expect: () => [
        const PaymentHistoryLoading(),
        isA<PaymentHistoryLoaded>()
            .having((s) => s.transactions.length, 'count', 2)
            .having((s) => s.totalAmount, 'totalAmount', 3000.0)
            .having((s) => s.totalTrainerEarnings, 'totalTrainerEarnings', 2700.0)
            .having((s) => s.totalPlatformFees, 'totalPlatformFees', 300.0)
            .having((s) => s.isTrainerMode, 'isTrainerMode', isTrue),
      ],
    );
  });
}

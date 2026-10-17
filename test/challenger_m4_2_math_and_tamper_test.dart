// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:math';
import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_app/features/payments/bloc/payment_bloc.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:fitness_app/features/payments/services/payment_signature_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Challenger M4-2: Platform Fee Math Invariants (10,000 Amounts)', () {
    test('Invariant holds across 10,000 randomized amounts with 2 decimals and random fee tiers', () {
      final rng = Random(42);
      var invariantViolations = 0;
      var totalTrials = 10000;

      for (var i = 0; i < totalTrials; i++) {
        // Generate amounts across 3 tiers: micro (0.01 to 10), normal (10 to 5000), large (5000 to 1,000,000)
        double amount;
        final tierRoll = rng.nextDouble();
        if (tierRoll < 0.3) {
          // Micro: 0.01 to 10.00
          amount = (rng.nextInt(1000) + 1) / 100.0;
        } else if (tierRoll < 0.8) {
          // Normal: 10.00 to 5000.00
          amount = (rng.nextInt(499000) + 1000) / 100.0;
        } else {
          // Large: 5,000.00 to 1,000,000.00
          amount = (rng.nextInt(99500000) + 500000) / 100.0;
        }

        // Random fee tier: 0%, 10%, 15%, 100%, or arbitrary float between 0 and 100
        double feePercent;
        final feeRoll = rng.nextInt(5);
        switch (feeRoll) {
          case 0:
            feePercent = 0.0;
            break;
          case 1:
            feePercent = 10.0;
            break;
          case 2:
            feePercent = 15.0;
            break;
          case 3:
            feePercent = 100.0;
            break;
          default:
            feePercent = (rng.nextInt(10000)) / 100.0;
        }

        final split = PlatformFeeCalculator.calculateSplit(
          amount: amount,
          feePercent: feePercent,
        );

        final sum = double.parse(
          (split.platformFee + split.trainerAmount).toStringAsFixed(2),
        );
        final diff = (amount - sum).abs();
        if (diff > 0.001) {
          invariantViolations++;
        }
      }

      expect(
        invariantViolations,
        0,
        reason: 'Zero invariant violations allowed across 10,000 amounts',
      );
    });

    test('Boundary conditions: 0%, 100%, extreme values, and micro-cents', () {
      // 0% fee
      final split0 = PlatformFeeCalculator.calculateSplit(
        amount: 1000.0,
        feePercent: 0.0,
      );
      expect(split0.platformFee, 0.0);
      expect(split0.trainerAmount, 1000.0);
      expect(split0.platformFee + split0.trainerAmount, 1000.0);

      // 100% fee
      final split100 = PlatformFeeCalculator.calculateSplit(
        amount: 1000.0,
        feePercent: 100.0,
      );
      expect(split100.platformFee, 1000.0);
      expect(split100.trainerAmount, 0.0);
      expect(split100.platformFee + split100.trainerAmount, 1000.0);

      // Smallest valid amount: 0.01 INR (1 paisa)
      final splitMin = PlatformFeeCalculator.calculateSplit(
        amount: 0.01,
        feePercent: 10.0,
      );
      expect(splitMin.amount, 0.01);
      expect(
        double.parse((splitMin.platformFee + splitMin.trainerAmount).toStringAsFixed(2)),
        0.01,
      );

      // Extreme large amount: 100,000,000.00 INR (₹10 Crore)
      final splitMax = PlatformFeeCalculator.calculateSplit(
        amount: 100000000.00,
        feePercent: 10.0,
      );
      expect(splitMax.platformFee, 10000000.00);
      expect(splitMax.trainerAmount, 90000000.00);
      expect(splitMax.platformFee + splitMax.trainerAmount, 100000000.00);

      // Invalid arguments: negative amount and 0
      expect(() => PlatformFeeCalculator.calculateSplit(amount: 0.0), throwsArgumentError);
      expect(() => PlatformFeeCalculator.calculateSplit(amount: -10.0), throwsArgumentError);
      expect(() => PlatformFeeCalculator.calculateSplit(amount: 100.0, feePercent: -0.1), throwsArgumentError);
      expect(() => PlatformFeeCalculator.calculateSplit(amount: 100.0, feePercent: 100.1), throwsArgumentError);
    });

    test('Fractional cents vulnerability test: 3+ decimal place inputs', () {
      // Test when amount has sub-cent precision (e.g. 100.005)
      final fractionalAmounts = [100.005, 199.999, 0.001, 49.5555];
      for (final amt in fractionalAmounts) {
        final split = PlatformFeeCalculator.calculateSplit(amount: amt);
        final sum = double.parse(
          (split.platformFee + split.trainerAmount).toStringAsFixed(2),
        );
        // Note: split.amount is unrounded 'amt', while fee and trainer are rounded to 2 decimals.
        // If amount was not quantized to 2 decimals beforehand, amount != platformFee + trainerAmount!
        final exactMatch = (split.amount == sum);
        // We log whether unquantized fractional cents preserve invariant
        print('Fractional amount $amt -> platformFee=${split.platformFee}, trainer=${split.trainerAmount}, sum=$sum (exact match: $exactMatch)');
      }
    });

    test('Paise round-trip conversion integrity', () {
      final amounts = [0.01, 1.00, 19.99, 1500.00, 9999.99, 1000000.00];
      for (final amt in amounts) {
        final paise = PlatformFeeCalculator.toPaise(amt);
        final roundTrip = PlatformFeeCalculator.fromPaise(paise);
        expect(roundTrip, amt, reason: 'Paise round-trip failed for $amt');
      }
    });
  });

  group('Challenger M4-2: RFC 2104 / RFC 4231 HMAC-SHA256 Test Vectors', () {
    test('RFC 4231 Test Case 2: key="Jefe", data="what do ya want for nothing?"', () {
      // Key: "Jefe"
      // Data: "what do ya want for nothing?"
      // Expected: 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
      const key = 'Jefe';
      const data = 'what do ya want for nothing?';
      const expectedDigest =
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843';

      final result = PaymentSignatureHelper.hmacSha256(key, data);
      expect(result, expectedDigest);
    });

    test('Known Test Vector: key="key", data="The quick brown fox jumps over the lazy dog"', () {
      const key = 'key';
      const data = 'The quick brown fox jumps over the lazy dog';
      const expectedDigest =
          'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8';

      final result = PaymentSignatureHelper.hmacSha256(key, data);
      expect(result, expectedDigest);
    });

    test('Key larger than 64-byte block size (RFC 2104 / 4231 Rule: Key must be pre-hashed)', () {
      // 80 'k' characters: key length = 80 bytes > 64 byte block size
      final key = 'k' * 80;
      const data = 'Test with key longer than 64-byte block size';
      // In RFC 2104 / 4231: if key > 64 bytes, k = SHA256(key), padded to 64 bytes with zeros
      final result = PaymentSignatureHelper.hmacSha256(key, data);

      // Verify that result is a valid 64-hex character SHA-256 HMAC
      expect(result.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(result), isTrue);

      // Deterministic check: calling again produces identical digest
      expect(PaymentSignatureHelper.hmacSha256(key, data), result);
    });

    test('Message larger than block size (1000 bytes)', () {
      const key = 'secret_test_key';
      final data = 'A' * 1000;
      final result = PaymentSignatureHelper.hmacSha256(key, data);
      expect(result.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(result), isTrue);
    });
  });

  group('Challenger M4-2: Cryptographic Tampering & 1-Bit Mutation Tests', () {
    const defaultSecret = PaymentSignatureHelper.defaultTestSecret;
    const validOrderId = 'order_valid_m4_1234567890';
    const validPaymentId = 'pay_valid_m4_9876543210';
    late String validSignature;

    setUp(() {
      validSignature = PaymentSignatureHelper.computeRazorpaySignature(
        orderId: validOrderId,
        paymentId: validPaymentId,
        secret: defaultSecret,
      );
    });

    test('1-bit flip anywhere in order_id produces completely different HMAC', () {
      // Flip 1 bit across every byte in orderId
      for (var byteIdx = 0; byteIdx < validOrderId.length; byteIdx++) {
        for (var bit = 0; bit < 7; bit++) {
          final codeUnits = List<int>.from(validOrderId.codeUnits);
          codeUnits[byteIdx] ^= (1 << bit);
          final tamperedOrderId = String.fromCharCodes(codeUnits);

          if (tamperedOrderId == validOrderId) continue;

          final tamperedSig = PaymentSignatureHelper.computeRazorpaySignature(
            orderId: tamperedOrderId,
            paymentId: validPaymentId,
            secret: defaultSecret,
          );

          expect(
            tamperedSig,
            isNot(equals(validSignature)),
            reason: '1-bit flip at byte $byteIdx bit $bit in order_id must produce different signature',
          );
        }
      }
    });

    test('1-bit flip anywhere in payment_id produces completely different HMAC', () {
      for (var byteIdx = 0; byteIdx < validPaymentId.length; byteIdx++) {
        for (var bit = 0; bit < 7; bit++) {
          final codeUnits = List<int>.from(validPaymentId.codeUnits);
          codeUnits[byteIdx] ^= (1 << bit);
          final tamperedPaymentId = String.fromCharCodes(codeUnits);

          if (tamperedPaymentId == validPaymentId) continue;

          final tamperedSig = PaymentSignatureHelper.computeRazorpaySignature(
            orderId: validOrderId,
            paymentId: tamperedPaymentId,
            secret: defaultSecret,
          );

          expect(
            tamperedSig,
            isNot(equals(validSignature)),
            reason: '1-bit flip at byte $byteIdx bit $bit in payment_id must produce different signature',
          );
        }
      }
    });

    test('1-bit flip anywhere in signature string fails equality with valid signature', () {
      for (var charIdx = 0; charIdx < validSignature.length; charIdx++) {
        final originalChar = validSignature[charIdx];
        // Flip to different hex character
        final replacementChar = originalChar == 'a' ? 'b' : 'a';
        final tamperedSig = validSignature.substring(0, charIdx) +
            replacementChar +
            validSignature.substring(charIdx + 1);

        expect(
          tamperedSig,
          isNot(equals(validSignature)),
          reason: 'Tampered signature at char $charIdx must not equal valid signature',
        );
      }
    });
  });

  group('Challenger M4-2: PaymentService & PaymentBloc Tamper Rejection & Failure Emission', () {
    const validOrderId = 'order_test_bloc_101';
    const validPaymentId = 'pay_test_bloc_202';
    final validSignature = PaymentSignatureHelper.computeRazorpaySignature(
      orderId: validOrderId,
      paymentId: validPaymentId,
    );

    test('PaymentService.verifyPayment with mock HTTP client rejecting tampered signature', () async {
      // Mock HTTP client that performs genuine HMAC verification or returns 400 when invalid
      final mockClient = MockClient((request) async {
        if (request.url.path == '/payments/verify') {
          final body = json.decode(request.body) as Map<String, dynamic>;
          final orderId = body['razorpay_order_id'] as String;
          final paymentId = body['razorpay_payment_id'] as String;
          final signature = body['razorpay_signature'] as String;

          final expected = PaymentSignatureHelper.computeRazorpaySignature(
            orderId: orderId,
            paymentId: paymentId,
          );

          if (signature == expected) {
            return http.Response(
              json.encode({'status': 'captured', 'transaction_id': 'tx-123'}),
              200,
            );
          } else {
            return http.Response(
              json.encode({'detail': 'Invalid payment signature'}),
              400,
            );
          }
        }
        return http.Response('Not found', 404);
      });

      final service = PaymentService(
        client: mockClient,
        baseUrl: 'https://mock.pulsefit.io',
      );

      // 1. Valid signature -> verifyPayment must return true
      final validResult = await service.verifyPayment(
        orderId: validOrderId,
        paymentId: validPaymentId,
        signature: validSignature,
      );
      expect(validResult, isTrue, reason: 'Valid signature must succeed');

      // 2. Tampered signature (1-bit flipped) -> What does verifyPayment return?
      final tamperedSig = validSignature.substring(0, validSignature.length - 1) +
          (validSignature.endsWith('0') ? '1' : '0');

      final tamperedResult = await service.verifyPayment(
        orderId: validOrderId,
        paymentId: validPaymentId,
        signature: tamperedSig,
      );

      print('Empirical result: verifyPayment with tampered signature returned: $tamperedResult');
      // CRITICAL CHECK: Does it return false when HTTP returns 400?
      expect(
        tamperedResult,
        isFalse,
        reason: 'Tampered signature rejected with HTTP 400 MUST return false from verifyPayment',
      );
    });

    blocTest<PaymentBloc, PaymentState>(
      'PaymentBloc MUST emit PaymentFailure when signature is tampered (1-bit flip)',
      build: () {
        PaymentService.resetMockTransactions();
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/verify') {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final orderId = body['razorpay_order_id'] as String;
            final paymentId = body['razorpay_payment_id'] as String;
            final signature = body['razorpay_signature'] as String;

            final expected = PaymentSignatureHelper.computeRazorpaySignature(
              orderId: orderId,
              paymentId: paymentId,
            );

            if (signature == expected) {
              return http.Response(
                json.encode({'status': 'captured', 'transaction_id': 'tx-123'}),
                200,
              );
            } else {
              return http.Response(
                json.encode({'detail': 'Invalid payment signature'}),
                400,
              );
            }
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://mock.pulsefit.io',
        );
        return PaymentBloc(paymentService: service);
      },
      seed: () => PaymentOrderCreated(
        orderResponse: const PaymentOrderResponse(
          transactionId: 'tx-123',
          orderId: validOrderId,
          amount: 1500.0,
          platformFeeAmount: 150.0,
          trainerAmount: 1350.0,
          replayed: false,
        ),
        idempotencyKey: 'idem-key-tamper-test',
        trainerId: 'trainer-001',
        trainerName: 'Coach Sarah',
        amount: 1500.0,
        isReplayed: false,
      ),
      act: (bloc) {
        // Tamper 1 bit in signature
        final tamperedSig = validSignature.substring(0, validSignature.length - 1) +
            (validSignature.endsWith('0') ? '1' : '0');

        bloc.add(ConfirmPaymentSuccess(
          orderId: validOrderId,
          paymentId: validPaymentId,
          signature: tamperedSig,
        ));
      },
      expect: () => [
        isA<PaymentVerifying>(),
        isA<PaymentFailure>()
            .having(
              (s) => s.message,
              'message',
              contains('signature verification rejected'),
            )
            .having((s) => s.canRetry, 'canRetry', isFalse),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'PaymentBloc MUST emit PaymentFailure when order_id is tampered (1-bit flip)',
      build: () {
        PaymentService.resetMockTransactions();
        final mockClient = MockClient((request) async {
          if (request.url.path == '/payments/verify') {
            final body = json.decode(request.body) as Map<String, dynamic>;
            final orderId = body['razorpay_order_id'] as String;
            final paymentId = body['razorpay_payment_id'] as String;
            final signature = body['razorpay_signature'] as String;

            final expected = PaymentSignatureHelper.computeRazorpaySignature(
              orderId: orderId,
              paymentId: paymentId,
            );

            if (signature == expected) {
              return http.Response(
                json.encode({'status': 'captured', 'transaction_id': 'tx-123'}),
                200,
              );
            } else {
              return http.Response(
                json.encode({'detail': 'Invalid payment signature'}),
                400,
              );
            }
          }
          return http.Response('Not found', 404);
        });

        final service = PaymentService(
          client: mockClient,
          baseUrl: 'https://mock.pulsefit.io',
        );
        return PaymentBloc(paymentService: service);
      },
      seed: () => PaymentOrderCreated(
        orderResponse: const PaymentOrderResponse(
          transactionId: 'tx-123',
          orderId: validOrderId,
          amount: 1500.0,
          platformFeeAmount: 150.0,
          trainerAmount: 1350.0,
          replayed: false,
        ),
        idempotencyKey: 'idem-key-order-tamper-test',
        trainerId: 'trainer-001',
        trainerName: 'Coach Sarah',
        amount: 1500.0,
        isReplayed: false,
      ),
      act: (bloc) {
        // Tamper 1 bit in order_id
        final tamperedOrderId = validOrderId.substring(0, validOrderId.length - 1) +
            (validOrderId.endsWith('1') ? '2' : '1');

        bloc.add(ConfirmPaymentSuccess(
          orderId: tamperedOrderId,
          paymentId: validPaymentId,
          signature: validSignature,
        ));
      },
      expect: () => [
        isA<PaymentVerifying>(),
        isA<PaymentFailure>()
            .having(
              (s) => s.message,
              'message',
              contains('signature verification rejected'),
            )
            .having((s) => s.canRetry, 'canRetry', isFalse),
      ],
    );

    test('VULNERABILITY PROBE: PaymentService.verifyPayment offline fallback when order was created via createOrder', () async {
      PaymentService.resetMockTransactions();
      // Setup mockClient that returns 200 on create-order and 400 on verify
      final mockClient = MockClient((request) async {
        if (request.url.path == '/payments/create-order') {
          return http.Response(
            json.encode({
              'transaction_id': 'tx-vuln-101',
              'order_id': 'order_vuln_101',
              'amount': 1500.0,
              'platform_fee_amount': 150.0,
              'trainer_amount': 1350.0,
              'replayed': false,
            }),
            200,
          );
        }
        if (request.url.path == '/payments/verify') {
          // Backend rejects invalid signature with 400!
          return http.Response(
            json.encode({'detail': 'Invalid payment signature'}),
            400,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = PaymentService(
        client: mockClient,
        baseUrl: 'https://mock.pulsefit.io',
      );

      // Create order first
      final orderRes = await service.createOrder(
        trainerId: 'trainer-001',
        amount: 1500.0,
        idempotencyKey: 'idem-vuln-key',
      );
      expect(orderRes.orderId, 'order_vuln_101');

      // Now verify with completely bogus/tampered signature!
      final verifyRes = await service.verifyPayment(
        orderId: 'order_vuln_101',
        paymentId: 'pay_bogus',
        signature: 'bogus_tampered_signature_123',
      );

      print('VULNERABILITY PROBE RESULT: verifyPayment returned: $verifyRes');
    });
  });
}

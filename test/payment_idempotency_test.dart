import 'dart:convert';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:fitness_app/features/payments/services/payment_signature_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PlatformFeeCalculator Tests', () {
    test('standard 10% fee calculation on ₹1,500.00', () {
      final split = PlatformFeeCalculator.calculateSplit(amount: 1500.0);
      expect(split.amount, 1500.0);
      expect(split.platformFee, 150.0);
      expect(split.trainerAmount, 1350.0);
      expect(split.platformFee + split.trainerAmount, 1500.0);
    });

    test('fractional amount rounding on ₹199.99 with 10% fee', () {
      final split = PlatformFeeCalculator.calculateSplit(amount: 199.99);
      expect(split.amount, 199.99);
      expect(split.platformFee, 20.00); // 19.999 -> rounds to 20.00
      expect(split.trainerAmount, 179.99);
      expect(
        double.parse((split.platformFee + split.trainerAmount).toStringAsFixed(2)),
        199.99,
      );
    });

    test('custom fee percentage 15% on ₹2,500.00', () {
      final split = PlatformFeeCalculator.calculateSplit(
        amount: 2500.0,
        feePercent: 15.0,
      );
      expect(split.platformFee, 375.0);
      expect(split.trainerAmount, 2125.0);
      expect(split.platformFee + split.trainerAmount, 2500.0);
    });

    test('zero percent fee returns full amount to trainer', () {
      final split = PlatformFeeCalculator.calculateSplit(
        amount: 1000.0,
        feePercent: 0.0,
      );
      expect(split.platformFee, 0.0);
      expect(split.trainerAmount, 1000.0);
    });

    test('100 percent fee assigns full amount to platform', () {
      final split = PlatformFeeCalculator.calculateSplit(
        amount: 500.0,
        feePercent: 100.0,
      );
      expect(split.platformFee, 500.0);
      expect(split.trainerAmount, 0.0);
    });

    test('converts INR amounts to integer Paise correctly', () {
      expect(PlatformFeeCalculator.toPaise(1500.0), 150000);
      expect(PlatformFeeCalculator.toPaise(150.0), 15000);
      expect(PlatformFeeCalculator.toPaise(199.99), 19999);
      expect(PlatformFeeCalculator.toPaise(20.00), 2000);
      expect(PlatformFeeCalculator.fromPaise(150000), 1500.0);
      expect(PlatformFeeCalculator.fromPaise(19999), 199.99);
    });

    test('rejects negative or zero amount', () {
      expect(
        () => PlatformFeeCalculator.calculateSplit(amount: 0.0),
        throwsArgumentError,
      );
      expect(
        () => PlatformFeeCalculator.calculateSplit(amount: -50.0),
        throwsArgumentError,
      );
    });

    test('rejects fee percent outside 0 to 100', () {
      expect(
        () => PlatformFeeCalculator.calculateSplit(amount: 100.0, feePercent: -1.0),
        throwsArgumentError,
      );
      expect(
        () => PlatformFeeCalculator.calculateSplit(amount: 100.0, feePercent: 105.0),
        throwsArgumentError,
      );
    });

    test('preserves mathematical invariant: amount == fee + trainer across varied amounts', () {
      final testAmounts = [10.0, 49.99, 99.50, 150.75, 599.95, 1200.0, 3456.78, 9999.99];
      for (final amt in testAmounts) {
        final split = PlatformFeeCalculator.calculateSplit(amount: amt);
        final sum = double.parse((split.platformFee + split.trainerAmount).toStringAsFixed(2));
        expect(sum, amt, reason: 'Split sum must exactly match amount for $amt');
      }
    });
  });

  group('Payment Models & Serialization Tests', () {
    test('PaymentOrderPayload serializes and deserializes faithfully', () {
      const payload = PaymentOrderPayload(
        trainerId: 'trainer-uuid-1234',
        amount: 2500.0,
        idempotencyKey: 'idem-uuid-5678',
        currency: 'INR',
        notes: {'service': '1-on-1 Coaching', 'session_count': 5},
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['trainer_id'], 'trainer-uuid-1234');
      expect(jsonMap['amount'], 2500.0);
      expect(jsonMap['idempotency_key'], 'idem-uuid-5678');
      expect(jsonMap['currency'], 'INR');
      expect(jsonMap['notes']['service'], '1-on-1 Coaching');

      final reconstructed = PaymentOrderPayload.fromJson(jsonMap);
      expect(reconstructed.trainerId, payload.trainerId);
      expect(reconstructed.amount, payload.amount);
      expect(reconstructed.idempotencyKey, payload.idempotencyKey);
    });

    test('PaymentOrderResponse deserializes faithfully with replayed flag', () {
      final responseJson = {
        'transaction_id': 'tx-uuid-999',
        'order_id': 'order_rzp_111',
        'amount': 1500.0,
        'platform_fee_amount': 150.0,
        'trainer_amount': 1350.0,
        'replayed': true,
      };

      final parsed = PaymentOrderResponse.fromJson(responseJson);
      expect(parsed.transactionId, 'tx-uuid-999');
      expect(parsed.orderId, 'order_rzp_111');
      expect(parsed.amount, 1500.0);
      expect(parsed.platformFeeAmount, 150.0);
      expect(parsed.trainerAmount, 1350.0);
      expect(parsed.replayed, isTrue);

      final reEncoded = parsed.toJson();
      expect(reEncoded['replayed'], isTrue);
      expect(reEncoded['transaction_id'], 'tx-uuid-999');
    });

    test('PaymentConfig defaults and JSON serialization', () {
      final defaultConfig = PaymentConfig.defaultMock();
      expect(defaultConfig.platformFeePercentage, 10.0);
      expect(defaultConfig.currency, 'INR');
      expect(defaultConfig.razorpayKeyId, 'rzp_test_mock_key_12345');

      final customJson = {
        'platform_fee_percentage': 12.5,
        'currency': 'INR',
        'razorpay_key_id': 'rzp_live_abc123',
      };
      final customConfig = PaymentConfig.fromJson(customJson);
      expect(customConfig.platformFeePercentage, 12.5);
      expect(customConfig.razorpayKeyId, 'rzp_live_abc123');
    });

    test('PaymentVerifyPayload serializes required Razorpay fields', () {
      const verify = PaymentVerifyPayload(
        razorpayOrderId: 'order_123',
        razorpayPaymentId: 'pay_456',
        razorpaySignature: 'sig_789',
      );
      final json = verify.toJson();
      expect(json['razorpay_order_id'], 'order_123');
      expect(json['razorpay_payment_id'], 'pay_456');
      expect(json['razorpay_signature'], 'sig_789');
    });

    test('PaymentStatus enum parsing and dbValue', () {
      expect(PaymentStatus.fromString('captured'), PaymentStatus.captured);
      expect(PaymentStatus.fromString('SUCCESS'), PaymentStatus.captured);
      expect(PaymentStatus.fromString('paid'), PaymentStatus.captured);
      expect(PaymentStatus.fromString('authorized'), PaymentStatus.authorized);
      expect(PaymentStatus.fromString('failed'), PaymentStatus.failed);
      expect(PaymentStatus.fromString('refunded'), PaymentStatus.refunded);
      expect(PaymentStatus.fromString('created'), PaymentStatus.created);
      expect(PaymentStatus.fromString('unknown'), PaymentStatus.created);
      expect(PaymentStatus.captured.dbValue, 'captured');
    });

    test('PaymentTransaction model full lifecycle parsing and formatters', () {
      final txJson = {
        'id': 'tx-100',
        'idempotency_key': 'idem-key-abc',
        'user_id': 'user-1',
        'trainer_id': 'trainer-1',
        'order_id': 'order_100',
        'payment_id': 'pay_100',
        'razorpay_signature': 'sig_100',
        'amount': 2000.0,
        'currency': 'INR',
        'platform_fee': 200.0,
        'platform_fee_percent': 10.0,
        'trainer_amount': 1800.0,
        'status': 'captured',
        'trainer_name': 'Coach Sarah',
        'created_at': '2026-10-14T10:00:00.000Z',
      };

      final tx = PaymentTransaction.fromJson(txJson);
      expect(tx.id, 'tx-100');
      expect(tx.idempotencyKey, 'idem-key-abc');
      expect(tx.isCaptured, isTrue);
      expect(tx.isPending, isFalse);
      expect(tx.isFailed, isFalse);
      expect(tx.displayAmount, '₹2000.00');
      expect(tx.displayFee, '₹200.00');
      expect(tx.displayTrainerPayout, '₹1800.00');
      expect(tx.displayStatus, 'Paid');

      final copied = tx.copyWith(status: PaymentStatus.refunded);
      expect(copied.isRefunded, isTrue);
      expect(copied.displayStatus, 'Refunded');
    });
  });

  group('PaymentSignatureHelper Cryptographic Verification', () {
    test('computes known HMAC-SHA256 test vector faithfully', () {
      // RFC 2202 Test Case 2
      const key = 'key';
      const data = 'The quick brown fox jumps over the lazy dog';
      final digest = PaymentSignatureHelper.hmacSha256(key, data);
      expect(
        digest,
        'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8',
      );
    });

    test('computes razorpay signature for order and payment id', () {
      final signature = PaymentSignatureHelper.computeRazorpaySignature(
        orderId: 'order_test_123',
        paymentId: 'pay_test_456',
        secret: 'rzp_test_secret_998877665544',
      );
      expect(signature, isNotEmpty);
      expect(signature.length, 64); // 256 bits = 64 hex chars
    });
  });

  group('PaymentService Idempotency & Replay Mechanics', () {
    setUp(() {
      PaymentService.resetMockTransactions();
    });

    test('idempotency key adheres to UUID v4 format', () {
      final service = PaymentService(baseUrl: 'http://localhost:9999');
      final key = service.generateIdempotencyKey();
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegex.hasMatch(key), isTrue);
    });

    test('active key caching preserves same key per session context', () {
      final service = PaymentService(baseUrl: 'http://localhost:9999');
      const sessionKey = 'session_trainer_1';

      final key1 = service.getOrCreateActiveKey(sessionKey);
      final key2 = service.getOrCreateActiveKey(sessionKey);
      expect(key1, key2);

      service.clearActiveKey(sessionKey);
      final key3 = service.getOrCreateActiveKey(sessionKey);
      expect(key3, isNot(key1));
    });

    test('createOrder offline fallback records and replays idempotent order', () async {
      final service = PaymentService(baseUrl: 'http://localhost:9999');
      const testKey = 'unique-idempotency-key-001';

      // First attempt: creates new order
      final res1 = await service.createOrder(
        trainerId: 'trainer-abc',
        amount: 1500.0,
        idempotencyKey: testKey,
      );
      expect(res1.replayed, isFalse);
      expect(res1.amount, 1500.0);
      expect(res1.platformFeeAmount, 150.0);
      expect(res1.trainerAmount, 1350.0);

      // Second attempt with exact same key: must return cached order with replayed=true
      final res2 = await service.createOrder(
        trainerId: 'trainer-abc',
        amount: 1500.0,
        idempotencyKey: testKey,
      );
      expect(res2.replayed, isTrue);
      expect(res2.orderId, res1.orderId);
      expect(res2.transactionId, res1.transactionId);
      expect(res2.amount, res1.amount);
      expect(res2.platformFeeAmount, res1.platformFeeAmount);
      expect(res2.trainerAmount, res1.trainerAmount);
    });

    test('verifyPayment updates transaction status to captured', () async {
      final service = PaymentService(baseUrl: 'http://localhost:9999');
      const testKey = 'unique-idempotency-key-002';

      final order = await service.createOrder(
        trainerId: 'trainer-xyz',
        amount: 2000.0,
        idempotencyKey: testKey,
      );

      final verified = await service.verifyPayment(
        orderId: order.orderId,
        paymentId: 'pay_mock_123',
        signature: 'sig_mock_456',
      );
      expect(verified, isTrue);

      final history = await service.getHistory();
      final capturedTx = history.firstWhere((tx) => tx.orderId == order.orderId);
      expect(capturedTx.isCaptured, isTrue);
      expect(capturedTx.paymentId, 'pay_mock_123');
    });

    test('online HTTP client interacts with FastAPI payment router contracts', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/payments/config') {
          return http.Response(
            json.encode({
              'platform_fee_percentage': 10.0,
              'currency': 'INR',
              'razorpay_key_id': 'rzp_test_online_123',
            }),
            200,
          );
        }
        if (request.url.path == '/payments/create-order') {
          final body = json.decode(request.body) as Map<String, dynamic>;
          final amt = (body['amount'] as num).toDouble();
          final split = PlatformFeeCalculator.calculateSplit(amount: amt);
          return http.Response(
            json.encode({
              'transaction_id': 'tx_online_555',
              'order_id': 'order_online_777',
              'amount': split.amount,
              'platform_fee_amount': split.platformFee,
              'trainer_amount': split.trainerAmount,
              'replayed': false,
            }),
            200,
          );
        }
        if (request.url.path == '/payments/verify') {
          return http.Response(
            json.encode({
              'status': 'captured',
              'transaction_id': 'tx_online_555',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final onlineService = PaymentService(
        client: mockClient,
        baseUrl: 'https://mock.pulsefit.io',
      );

      final config = await onlineService.fetchConfig();
      expect(config.razorpayKeyId, 'rzp_test_online_123');

      final order = await onlineService.createOrder(
        trainerId: 'trainer_online_1',
        amount: 3000.0,
        idempotencyKey: 'idem_online_99',
      );
      expect(order.orderId, 'order_online_777');
      expect(order.amount, 3000.0);
      expect(order.platformFeeAmount, 300.0);
      expect(order.trainerAmount, 2700.0);
      expect(order.replayed, isFalse);

      final verified = await onlineService.verifyPayment(
        orderId: order.orderId,
        paymentId: 'pay_online_123',
        signature: 'sig_online_123',
      );
      expect(verified, isTrue);
    });

    test('generates valid Razorpay Route transfer structure', () {
      final split = PlatformFeeCalculator.calculateSplit(amount: 2000.0);
      final trainerPaise = PlatformFeeCalculator.toPaise(split.trainerAmount);

      final routePayload = {
        'amount': PlatformFeeCalculator.toPaise(split.amount),
        'currency': 'INR',
        'transfers': [
          {
            'account': 'acc_test_trainer_123',
            'amount': trainerPaise,
            'currency': 'INR',
            'on_hold': 0,
          }
        ],
      };

      expect(routePayload['amount'], 200000);
      final transfers = routePayload['transfers'] as List<Map<String, dynamic>>;
      expect(transfers.length, 1);
      expect(transfers[0]['account'], 'acc_test_trainer_123');
      expect(transfers[0]['amount'], 180000); // ₹1,800 in paise
    });
  });
}

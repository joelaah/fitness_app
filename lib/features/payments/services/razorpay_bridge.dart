import 'package:fitness_app/features/payments/screens/razorpay_sandbox_dialog.dart';
import 'package:flutter/material.dart';

/// Response payload returned on successful Razorpay checkout.
class PaymentSuccessResponse {
  const PaymentSuccessResponse({
    required this.orderId,
    required this.paymentId,
    required this.signature,
    this.rawResponse,
  });

  final String orderId;
  final String paymentId;
  final String signature;
  final Map<String, dynamic>? rawResponse;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'order_id': orderId,
    'payment_id': paymentId,
    'signature': signature,
    if (rawResponse != null) 'raw': rawResponse,
  };
}

/// Response payload returned on failed or cancelled Razorpay checkout.
class PaymentFailureResponse {
  const PaymentFailureResponse({
    required this.code,
    required this.message,
    this.details,
  });

  final int code;
  final String message;
  final Map<String, dynamic>? details;

  static const int codeCancelled = 0;
  static const int codeNetworkError = 1;
  static const int codePaymentFailed = 2;

  bool get isCancelled => code == codeCancelled;
}

/// Options passed into [RazorpayBridge.openCheckout].
class RazorpayCheckoutOptions {
  const RazorpayCheckoutOptions({
    required this.keyId,
    required this.orderId,
    required this.amount,
    this.currency = 'INR',
    this.name = 'PulseFit AI',
    this.description = 'Personal Training Session',
    this.trainerId,
    this.trainerName,
    this.userEmail,
    this.userContact,
    this.notes,
  });

  final String keyId;
  final String orderId;
  final double amount; // in standard currency (e.g. 1500.0)
  final String currency; // 'INR'
  final String name; // 'PulseFit AI'
  final String description; // e.g. '1-on-1 Coaching with Coach Marcus'
  final String? trainerId;
  final String? trainerName;
  final String? userEmail;
  final String? userContact;
  final Map<String, dynamic>? notes;

  int get amountInPaise => (amount * 100).round();
}

/// Abstract cross-platform bridge for Razorpay checkout.
abstract class RazorpayBridge {
  factory RazorpayBridge() = RazorpayBridgeWeb;

  /// Opens the checkout flow.
  /// On Web/Desktop: Opens the realistic Razorpay Web Sandbox dialog.
  /// On Mobile (with plugin): Can delegate to native Razorpay SDK.
  Future<void> openCheckout({
    required BuildContext context,
    required RazorpayCheckoutOptions options,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  });

  void dispose();
}

/// Web & Sandbox implementation of [RazorpayBridge].
/// Presents the realistic Razorpay sandbox checkout dialog.
class RazorpayBridgeWeb implements RazorpayBridge {
  @override
  Future<void> openCheckout({
    required BuildContext context,
    required RazorpayCheckoutOptions options,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RazorpaySandboxDialog(options: options),
    );

    if (result == null || result['status'] == 'cancelled') {
      onError(
        const PaymentFailureResponse(
          code: PaymentFailureResponse.codeCancelled,
          message: 'Payment cancelled by user.',
        ),
      );
      return;
    }

    if (result['status'] == 'failed') {
      onError(
        PaymentFailureResponse(
          code: PaymentFailureResponse.codePaymentFailed,
          message: (result['message'] as String?) ??
              'Payment authorization failed.',
          details: result,
        ),
      );
      return;
    }

    if (result['status'] == 'success') {
      onSuccess(
        PaymentSuccessResponse(
          orderId: (result['order_id'] ?? options.orderId) as String,
          paymentId: result['payment_id'] as String,
          signature: result['signature'] as String,
          rawResponse: result,
        ),
      );
    }
  }

  @override
  void dispose() {}
}

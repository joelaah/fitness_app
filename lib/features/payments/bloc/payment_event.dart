import 'package:equatable/equatable.dart';

/// Base class for all payment events in the BLoC state machine.
abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to initiate order creation with idempotency key generation
/// or reuse.
class InitiatePayment extends PaymentEvent {
  const InitiatePayment({
    required this.trainerId,
    required this.trainerName,
    required this.amount,
    this.idempotencyKey,
    this.sessionContextKey,
    this.sessionCount = 1,
    this.notes,
  });

  final String trainerId;
  final String trainerName;
  final double amount;
  final String? idempotencyKey;
  final String? sessionContextKey;
  final int sessionCount;
  final Map<String, dynamic>? notes;

  @override
  List<Object?> get props => [
    trainerId,
    trainerName,
    amount,
    idempotencyKey,
    sessionContextKey,
    sessionCount,
    notes,
  ];
}

/// Dispatched when the payment gateway reports successful client authorization.
class ConfirmPaymentSuccess extends PaymentEvent {
  const ConfirmPaymentSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
    this.rawResponse,
  });

  final String orderId;
  final String paymentId;
  final String signature;
  final Map<String, dynamic>? rawResponse;

  @override
  List<Object?> get props => [orderId, paymentId, signature, rawResponse];
}

/// Dispatched when the payment gateway fails or the user cancels.
class PaymentFailedEvent extends PaymentEvent {
  const PaymentFailedEvent({
    required this.code,
    required this.message,
    this.details,
  });

  final int code;
  final String message;
  final Map<String, dynamic>? details;

  bool get isCancelled => code == 0;

  @override
  List<Object?> get props => [code, message, details];
}

/// Dispatched to retry payment after an error, strictly preserving the
/// active idempotency key.
class RetryPayment extends PaymentEvent {
  const RetryPayment({this.sessionContextKey});

  final String? sessionContextKey;

  @override
  List<Object?> get props => [sessionContextKey];
}

/// Dispatched to cancel an in-flight payment and release cached
/// idempotency locks.
class CancelPayment extends PaymentEvent {
  const CancelPayment({this.sessionContextKey});

  final String? sessionContextKey;

  @override
  List<Object?> get props => [sessionContextKey];
}

/// Resets payment state back to initial idle.
class ResetPayment extends PaymentEvent {
  const ResetPayment();
}

/// Dispatched to query user transactions or trainer earnings ledger.
class LoadPaymentHistory extends PaymentEvent {
  const LoadPaymentHistory({
    this.forceRefresh = false,
    this.filterStatus,
    this.isTrainerMode = false,
  });

  final bool forceRefresh;
  final String? filterStatus;
  final bool isTrainerMode;

  @override
  List<Object?> get props => [forceRefresh, filterStatus, isTrainerMode];
}

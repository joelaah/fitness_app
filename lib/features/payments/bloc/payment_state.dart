import 'package:equatable/equatable.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';

/// Base class for all states in the payment BLoC state machine.
abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

/// Initial idle state.
class PaymentInitial extends PaymentState {
  const PaymentInitial();
}

/// Emitted while calling backend /payments/create-order.
class PaymentOrderCreating extends PaymentState {
  const PaymentOrderCreating({
    required this.idempotencyKey,
    required this.trainerId,
    required this.amount,
  });

  final String idempotencyKey;
  final String trainerId;
  final double amount;

  @override
  List<Object?> get props => [idempotencyKey, trainerId, amount];
}

/// Emitted when an order has been successfully created or replayed.
class PaymentOrderCreated extends PaymentState {
  const PaymentOrderCreated({
    required this.orderResponse,
    required this.idempotencyKey,
    required this.trainerId,
    required this.trainerName,
    required this.amount,
    required this.isReplayed,
  });

  final PaymentOrderResponse orderResponse;
  final String idempotencyKey;
  final String trainerId;
  final String trainerName;
  final double amount;
  final bool isReplayed;

  @override
  List<Object?> get props => [
    orderResponse,
    idempotencyKey,
    trainerId,
    trainerName,
    amount,
    isReplayed,
  ];
}

/// Emitted while the Razorpay checkout bridge modal / dialog is actively presented.
class PaymentCheckoutInProgress extends PaymentState {
  const PaymentCheckoutInProgress({
    required this.orderId,
    required this.idempotencyKey,
  });

  final String orderId;
  final String idempotencyKey;

  @override
  List<Object?> get props => [orderId, idempotencyKey];
}

/// Emitted while backend HMAC-SHA256 signature verification is underway.
class PaymentVerifying extends PaymentState {
  const PaymentVerifying({
    required this.orderId,
    required this.paymentId,
  });

  final String orderId;
  final String paymentId;

  @override
  List<Object?> get props => [orderId, paymentId];
}

/// Emitted when the payment is confirmed, captured, and permanently recorded.
class PaymentSuccess extends PaymentState {
  const PaymentSuccess({
    required this.transaction,
    this.message = 'Payment captured successfully.',
  });

  final PaymentTransaction transaction;
  final String message;

  @override
  List<Object?> get props => [transaction, message];
}

/// Emitted on payment gateway decline, network timeout, or signature mismatch.
/// Preserves [cachedIdempotencyKey] so that retries never result in duplicate
/// charges.
class PaymentFailure extends PaymentState {
  const PaymentFailure({
    required this.message,
    this.errorCode = 1,
    this.canRetry = true,
    this.cachedIdempotencyKey,
    this.partialOrder,
  });

  final String message;
  final int errorCode;
  final bool canRetry;
  final String? cachedIdempotencyKey;
  final PaymentOrderResponse? partialOrder;

  @override
  List<Object?> get props => [
    message,
    errorCode,
    canRetry,
    cachedIdempotencyKey,
    partialOrder,
  ];
}

/// Emitted while querying payment history / earnings ledger.
class PaymentHistoryLoading extends PaymentState {
  const PaymentHistoryLoading();
}

/// Emitted when payment transactions have loaded.
class PaymentHistoryLoaded extends PaymentState {
  const PaymentHistoryLoaded({
    required this.transactions,
    required this.totalAmount,
    required this.totalTrainerEarnings,
    required this.totalPlatformFees,
    this.isTrainerMode = false,
    this.activeFilter = 'All',
  });

  final List<PaymentTransaction> transactions;
  final double totalAmount;
  final double totalTrainerEarnings;
  final double totalPlatformFees;
  final bool isTrainerMode;
  final String activeFilter;

  @override
  List<Object?> get props => [
    transactions,
    totalAmount,
    totalTrainerEarnings,
    totalPlatformFees,
    isTrainerMode,
    activeFilter,
  ];

  PaymentHistoryLoaded copyWith({
    List<PaymentTransaction>? transactions,
    double? totalAmount,
    double? totalTrainerEarnings,
    double? totalPlatformFees,
    bool? isTrainerMode,
    String? activeFilter,
  }) {
    return PaymentHistoryLoaded(
      transactions: transactions ?? this.transactions,
      totalAmount: totalAmount ?? this.totalAmount,
      totalTrainerEarnings: totalTrainerEarnings ?? this.totalTrainerEarnings,
      totalPlatformFees: totalPlatformFees ?? this.totalPlatformFees,
      isTrainerMode: isTrainerMode ?? this.isTrainerMode,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

/// Emitted when query for payment history fails.
class PaymentHistoryError extends PaymentState {
  const PaymentHistoryError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fitness_app/core/network/resilient_network_client.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';

/// BLoC orchestrating payment lifecycle, order creation, Razorpay verification,
/// idempotency preservation during retries, and transaction ledger.
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc({PaymentService? paymentService})
    : _paymentService = paymentService ?? PaymentService(),
      super(const PaymentInitial()) {
    on<InitiatePayment>(_onInitiatePayment);
    on<ConfirmPaymentSuccess>(_onConfirmPaymentSuccess);
    on<PaymentFailedEvent>(_onPaymentFailed);
    on<RetryPayment>(_onRetryPayment);
    on<CancelPayment>(_onCancelPayment);
    on<ResetPayment>(_onResetPayment);
    on<LoadPaymentHistory>(_onLoadPaymentHistory);
  }

  final PaymentService _paymentService;

  // Cached state for idempotent retries
  InitiatePayment? _lastInitiateEvent;
  String? _activeIdempotencyKey;
  PaymentOrderResponse? _lastOrderResponse;

  String? get activeIdempotencyKey => _activeIdempotencyKey;
  PaymentOrderResponse? get lastOrderResponse => _lastOrderResponse;

  Future<void> _onInitiatePayment(
    InitiatePayment event,
    Emitter<PaymentState> emit,
  ) async {
    // 1. Resolve or preserve idempotency key
    final String key;
    if (_activeIdempotencyKey != null) {
      key = _activeIdempotencyKey!;
    } else if (event.idempotencyKey != null) {
      key = event.idempotencyKey!;
    } else if (event.sessionContextKey != null) {
      key = _paymentService.getOrCreateActiveKey(event.sessionContextKey!);
    } else {
      key = _paymentService.generateIdempotencyKey();
    }

    _activeIdempotencyKey = key;
    _lastInitiateEvent = event;

    emit(
      PaymentOrderCreating(
        idempotencyKey: key,
        trainerId: event.trainerId,
        amount: event.amount,
      ),
    );

    try {
      final response = await _paymentService.createOrder(
        trainerId: event.trainerId,
        amount: event.amount,
        idempotencyKey: key,
        sessionContextKey: event.sessionContextKey,
        notes:
            event.notes ??
            {
              'trainer_name': event.trainerName,
              'session_count': event.sessionCount,
            },
      );

      if (isClosed || state is PaymentInitial || _activeIdempotencyKey != key) {
        return;
      }

      _lastOrderResponse = response;

      emit(
        PaymentOrderCreated(
          orderResponse: response,
          idempotencyKey: key,
          trainerId: event.trainerId,
          trainerName: event.trainerName,
          amount: event.amount,
          isReplayed: response.replayed,
        ),
      );
    } on Exception catch (e) {
      if (isClosed || state is PaymentInitial || _activeIdempotencyKey != key) {
        return;
      }
      emit(
        PaymentFailure(
          message: ResilientNetworkClient.formatFriendlyErrorMessage(
            e,
            fallback: 'Failed to create payment order. Please try again.',
          ),
          cachedIdempotencyKey: key,
        ),
      );
    }
  }

  Future<void> _onConfirmPaymentSuccess(
    ConfirmPaymentSuccess event,
    Emitter<PaymentState> emit,
  ) async {
    final currentState = state;
    final resolvedAmount =
        _lastOrderResponse?.amount ??
        (currentState is PaymentOrderCreated ? currentState.amount : null) ??
        _lastInitiateEvent?.amount ??
        0.0;
    final resolvedTrainerId =
        _lastInitiateEvent?.trainerId ??
        (currentState is PaymentOrderCreated ? currentState.trainerId : '');
    final resolvedTrainerName =
        _lastInitiateEvent?.trainerName ??
        (currentState is PaymentOrderCreated ? currentState.trainerName : null);
    final resolvedTxId =
        _lastOrderResponse?.transactionId ??
        (currentState is PaymentOrderCreated
            ? currentState.orderResponse.transactionId
            : _paymentService.generateIdempotencyKey());
    final resolvedReplayed =
        _lastOrderResponse?.replayed ??
        (currentState is PaymentOrderCreated && currentState.isReplayed);
    final resolvedIdempotencyKey =
        _activeIdempotencyKey ??
        (currentState is PaymentOrderCreated
            ? currentState.idempotencyKey
            : '');

    emit(
      PaymentVerifying(
        orderId: event.orderId,
        paymentId: event.paymentId,
      ),
    );

    try {
      final isVerified = await _paymentService.verifyPayment(
        orderId: event.orderId,
        paymentId: event.paymentId,
        signature: event.signature,
      );

      if (isVerified) {
        final split = resolvedAmount > 0
            ? PlatformFeeCalculator.calculateSplit(amount: resolvedAmount)
            : (amount: 0.0, platformFee: 0.0, trainerAmount: 0.0);

        final transaction = PaymentTransaction(
          id: resolvedTxId,
          idempotencyKey: resolvedIdempotencyKey,
          userId: 'user_current',
          trainerId: resolvedTrainerId,
          orderId: event.orderId,
          razorpayOrderId: event.orderId,
          paymentId: event.paymentId,
          razorpayPaymentId: event.paymentId,
          razorpaySignature: event.signature,
          amount: split.amount,
          platformFee: split.platformFee,
          platformFeeAmount: split.platformFee,
          trainerAmount: split.trainerAmount,
          status: PaymentStatus.captured,
          trainerName: resolvedTrainerName,
          createdAt: DateTime.now().toUtc(),
          isReplayed: resolvedReplayed,
        );

        // Terminal success: clear cached session context key
        if (_lastInitiateEvent?.sessionContextKey != null) {
          _paymentService.clearActiveKey(
            _lastInitiateEvent!.sessionContextKey!,
          );
        }
        _activeIdempotencyKey = null;
        _lastInitiateEvent = null;
        _lastOrderResponse = null;

        emit(
          PaymentSuccess(
            transaction: transaction,
            message: 'Payment of ${transaction.displayAmount} '
                'captured successfully.',
          ),
        );
      } else {
        emit(
          PaymentFailure(
            message:
                'Cryptographic signature verification rejected by gateway.',
            errorCode: 2,
            canRetry: false,
            cachedIdempotencyKey: _activeIdempotencyKey,
          ),
        );
      }
    } on Exception catch (e) {
      emit(
        PaymentFailure(
          message: ResilientNetworkClient.formatFriendlyErrorMessage(
            e,
            fallback: 'Payment verification failed. Please try again.',
          ),
          errorCode: 2,
          cachedIdempotencyKey: _activeIdempotencyKey,
        ),
      );
    }
  }

  void _onPaymentFailed(
    PaymentFailedEvent event,
    Emitter<PaymentState> emit,
  ) {
    emit(
      PaymentFailure(
        message: event.message,
        errorCode: event.code,
        canRetry: !event.isCancelled,
        cachedIdempotencyKey: _activeIdempotencyKey,
        partialOrder: _lastOrderResponse,
      ),
    );
  }

  Future<void> _onRetryPayment(
    RetryPayment event,
    Emitter<PaymentState> emit,
  ) async {
    if (_lastInitiateEvent != null) {
      // Re-invoke initiation with preserved idempotency key
      await _onInitiatePayment(_lastInitiateEvent!, emit);
    } else {
      emit(
        const PaymentFailure(
          message: 'No previous payment session available to retry.',
          canRetry: false,
        ),
      );
    }
  }

  void _onCancelPayment(
    CancelPayment event,
    Emitter<PaymentState> emit,
  ) {
    final ctxKey =
        event.sessionContextKey ?? _lastInitiateEvent?.sessionContextKey;
    if (ctxKey != null) {
      _paymentService.clearActiveKey(ctxKey);
    }
    _activeIdempotencyKey = null;
    _lastInitiateEvent = null;
    _lastOrderResponse = null;
    emit(const PaymentInitial());
  }

  void _onResetPayment(
    ResetPayment event,
    Emitter<PaymentState> emit,
  ) {
    _activeIdempotencyKey = null;
    _lastInitiateEvent = null;
    _lastOrderResponse = null;
    emit(const PaymentInitial());
  }

  Future<void> _onLoadPaymentHistory(
    LoadPaymentHistory event,
    Emitter<PaymentState> emit,
  ) async {
    emit(const PaymentHistoryLoading());
    try {
      final rawTransactions = await _paymentService.getHistory(
        forceRefresh: event.forceRefresh,
      );

      final filter = event.filterStatus ?? 'All';
      final filtered = filter == 'All'
          ? rawTransactions
          : rawTransactions.where((tx) {
              if (filter == 'Paid') return tx.isCaptured;
              if (filter == 'Pending') return tx.isPending;
              if (filter == 'Failed') return tx.isFailed;
              return true;
            }).toList();

      final totalAmt = filtered.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final totalTrainer = filtered.fold<double>(
        0,
        (sum, item) => sum + item.trainerAmount,
      );
      final totalFee = filtered.fold<double>(
        0,
        (sum, item) => sum + item.platformFee,
      );

      emit(
        PaymentHistoryLoaded(
          transactions: filtered,
          totalAmount: totalAmt,
          totalTrainerEarnings: totalTrainer,
          totalPlatformFees: totalFee,
          isTrainerMode: event.isTrainerMode,
          activeFilter: filter,
        ),
      );
    } on Exception catch (e) {
      emit(PaymentHistoryError(message: 'Failed to load payment history: $e'));
    }
  }
}

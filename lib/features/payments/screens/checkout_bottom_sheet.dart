import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/core/widgets/secondary_button.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:fitness_app/features/payments/services/razorpay_bridge.dart';
import 'package:fitness_app/features/payments/widgets/fee_split_breakdown.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:flutter/material.dart';

/// Checkout phase enum for state machine rendering
enum CheckoutPhase {
  configuration,
  creatingOrder,
  checkoutActive,
  verifyingSignature,
  success,
  failure,
}

/// Checkout Bottom Sheet:
/// Displays trainer information, interactive session duration/count selector,
/// real-time 10% platform fee calculation (Total == Coach + Fee),
/// active idempotency key badge, Razorpay checkout invocation, and error/retry.
class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({
    required this.trainer,
    super.key,
    this.initialSessionCount = 1,
    this.paymentService,
    this.razorpayBridge,
    this.onPaymentCompleted,
  });

  final TrainerProfile trainer;
  final int initialSessionCount;
  final PaymentService? paymentService;
  final RazorpayBridge? razorpayBridge;
  final ValueChanged<PaymentTransaction>? onPaymentCompleted;

  /// Static helper to display the sheet responsively on mobile or web
  static Future<PaymentTransaction?> show(
    BuildContext context, {
    required TrainerProfile trainer,
    int initialSessionCount = 1,
    PaymentService? paymentService,
    RazorpayBridge? razorpayBridge,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      return showDialog<PaymentTransaction>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(150),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CheckoutBottomSheet(
                trainer: trainer,
                initialSessionCount: initialSessionCount,
                paymentService: paymentService,
                razorpayBridge: razorpayBridge,
                onPaymentCompleted: (tx) => Navigator.of(ctx).pop(tx),
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<PaymentTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: CheckoutBottomSheet(
          trainer: trainer,
          initialSessionCount: initialSessionCount,
          paymentService: paymentService,
          razorpayBridge: razorpayBridge,
          onPaymentCompleted: (tx) => Navigator.of(ctx).pop(tx),
        ),
      ),
    );
  }

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  late int _sessionCount;
  late final PaymentService _paymentService;
  late final RazorpayBridge _razorpayBridge;
  late String _sessionContextKey;
  late String _idempotencyKey;

  CheckoutPhase _phase = CheckoutPhase.configuration;
  String? _errorMessage;
  PaymentTransaction? _completedTransaction;

  String get _shortKey => _idempotencyKey.length >= 8
      ? _idempotencyKey.substring(0, 8)
      : _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _sessionCount = math.max(1, widget.initialSessionCount);
    _paymentService = widget.paymentService ?? PaymentService();
    _razorpayBridge = widget.razorpayBridge ?? RazorpayBridge();

    // Generate a unique session context key tied to this checkout modal
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _sessionContextKey = 'checkout_${widget.trainer.id}_$nowMs';
    _idempotencyKey = _paymentService.getOrCreateActiveKey(_sessionContextKey);
  }

  @override
  void dispose() {
    // If checkout didn't complete successfully, clean up active key
    if (_phase != CheckoutPhase.success) {
      _paymentService.clearActiveKey(_sessionContextKey);
    }
    super.dispose();
  }

  double get _grossAmount => widget.trainer.hourlyRate * _sessionCount;

  ({double amount, double platformFee, double trainerAmount}) get _split {
    return PlatformFeeCalculator.calculateSplit(
      amount: _grossAmount,
      feePercent: widget.trainer.platformFeePct,
    );
  }

  Future<void> _startCheckout() async {
    setState(() {
      _phase = CheckoutPhase.creatingOrder;
      _errorMessage = null;
    });

    try {
      // Step 1: Create idempotent order via backend / offline fallback
      final order = await _paymentService.createOrder(
        trainerId: widget.trainer.id,
        amount: _grossAmount,
        idempotencyKey: _idempotencyKey,
        sessionContextKey: _sessionContextKey,
        notes: {
          'trainer_name': widget.trainer.displayName ?? 'Coach',
          'session_count': _sessionCount,
          'hourly_rate': widget.trainer.hourlyRate,
        },
      );

      if (!mounted) return;
      setState(() {
        _phase = CheckoutPhase.checkoutActive;
      });

      // Step 2: Launch Razorpay checkout bridge modal
      final config = await _paymentService.fetchConfig();
      if (!mounted) return;

      await _razorpayBridge.openCheckout(
        context: context,
        options: RazorpayCheckoutOptions(
          keyId: config.razorpayKeyId,
          orderId: order.orderId,
          amount: order.amount,
          trainerId: widget.trainer.id,
          trainerName: widget.trainer.displayName ?? 'Certified Coach',
          description: '$_sessionCount Session(s) with '
              '${widget.trainer.displayName ?? "Coach"}',
        ),
        onSuccess: (paymentSuccess) async {
          if (!mounted) return;
          setState(() {
            _phase = CheckoutPhase.verifyingSignature;
          });

          // Step 3: Verify signature
          final isVerified = await _paymentService.verifyPayment(
            orderId: paymentSuccess.orderId,
            paymentId: paymentSuccess.paymentId,
            signature: paymentSuccess.signature,
          );

          if (!mounted) return;

          if (isVerified) {
            final tx = PaymentTransaction(
              id: order.transactionId,
              idempotencyKey: _idempotencyKey,
              userId: 'user_current',
              trainerId: widget.trainer.id,
              orderId: order.orderId,
              razorpayOrderId: order.orderId,
              paymentId: paymentSuccess.paymentId,
              razorpayPaymentId: paymentSuccess.paymentId,
              razorpaySignature: paymentSuccess.signature,
              amount: order.amount,
              platformFee: order.platformFeeAmount,
              platformFeeAmount: order.platformFeeAmount,
              trainerAmount: order.trainerAmount,
              status: PaymentStatus.captured,
              trainerName: widget.trainer.displayName,
              createdAt: DateTime.now().toUtc(),
              isReplayed: order.replayed,
            );

            _completedTransaction = tx;
            _paymentService.clearActiveKey(_sessionContextKey);

            setState(() {
              _phase = CheckoutPhase.success;
            });

            widget.onPaymentCompleted?.call(tx);
          } else {
            setState(() {
              _phase = CheckoutPhase.failure;
              _errorMessage = 'Cryptographic signature verification failed.';
            });
          }
        },
        onError: (paymentFailure) {
          if (!mounted) return;
          setState(() {
            _phase = CheckoutPhase.failure;
            _errorMessage = paymentFailure.message;
          });
        },
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = CheckoutPhase.failure;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _retryCheckout() {
    // Retrying safely re-uses the exact same active idempotency key
    _startCheckout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Drag Handle & Title
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book Coaching Session',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main View Switcher
          if (_phase == CheckoutPhase.success)
            _buildSuccessView(theme)
          else if (_phase == CheckoutPhase.failure)
            _buildFailureView(theme)
          else if (_phase == CheckoutPhase.creatingOrder ||
              _phase == CheckoutPhase.checkoutActive ||
              _phase == CheckoutPhase.verifyingSignature)
            _buildProgressView(theme)
          else
            _buildConfigurationView(theme),
        ],
      ),
    );
  }

  Widget _buildConfigurationView(ThemeData theme) {
    final trainer = widget.trainer;
    final split = _split;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coach Profile Preview Card
        ElevatedCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.coverPull,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  trainer.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trainer.displayName ?? 'Coach',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trainer.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.secondaryAccent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rate: ₹${trainer.hourlyRate.toStringAsFixed(0)} / hr',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trainer.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Session Count Selector
        Text(
          'NUMBER OF SESSIONS',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: _sessionCount > 1
                    ? AppColors.primary
                    : AppColors.textSecondary,
                onPressed: _sessionCount > 1
                    ? () => setState(() => _sessionCount--)
                    : null,
              ),
              Column(
                children: [
                  Text(
                    '$_sessionCount '
                    '${_sessionCount == 1 ? "Session" : "Sessions"}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_sessionCount * 60} minutes total 1-on-1 coaching',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: _sessionCount < 10
                    ? AppColors.primary
                    : AppColors.textSecondary,
                onPressed: _sessionCount < 10
                    ? () => setState(() => _sessionCount++)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Fee Split Breakdown Component
        FeeSplitBreakdownCard(
          hourlyRate: trainer.hourlyRate,
          sessionCount: _sessionCount,
          totalAmount: split.amount,
          trainerPayout: split.trainerAmount,
          platformFee: split.platformFee,
        ),
        const SizedBox(height: AppSpacing.md),

        // Idempotency Guarantee Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withAlpha(128),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.fingerprint_rounded,
                size: 16,
                color: AppColors.secondaryAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Idempotency Key: $_shortKey...',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Zero Double-Charge Guarantee',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Proceed to Pay Action Button
        PrimaryButton(
          label: 'Pay ₹${split.amount.toStringAsFixed(0)} with Razorpay',
          icon: Icons.lock_outline_rounded,
          onPressed: _startCheckout,
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Secured with 256-bit TLS • Test Sandbox Gateway',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressView(ThemeData theme) {
    var message = 'Preparing secure order...';
    if (_phase == CheckoutPhase.checkoutActive) {
      message = 'Awaiting Razorpay payment authorization...';
    } else if (_phase == CheckoutPhase.verifyingSignature) {
      message = 'Verifying cryptographic HMAC signature...';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Active Idempotency Key: $_shortKey...',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withAlpha(100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Could Not Be Completed',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage ??
                            'An unexpected network error occurred.',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Reassurance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.secondaryAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your active idempotency key ($_shortKey...) is '
                    'preserved. Retrying will NOT result in duplicate '
                    'charges.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Retry Payment (Safe)',
            icon: Icons.refresh_rounded,
            onPressed: _retryCheckout,
          ),
          const SizedBox(height: 8),
          Center(
            child: SecondaryButton(
              label: 'Cancel & Return',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    final tx = _completedTransaction;
    final coachPayout =
        (tx?.trainerAmount ?? _split.trainerAmount).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(40),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Confirmed!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have successfully booked $_sessionCount coaching session(s) '
            'with ${widget.trainer.displayName ?? "Coach"}.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),

          // Transaction Receipt Card
          ElevatedCard(
            child: Column(
              children: [
                _buildReceiptRow(
                  'Transaction ID',
                  tx != null && tx.id.length >= 18
                      ? tx.id.substring(0, 18)
                      : (tx?.id ?? 'tx_mock_123'),
                ),
                const Divider(color: AppColors.border, height: 16),
                _buildReceiptRow(
                  'Razorpay Order',
                  tx?.orderId ?? 'order_mock_123',
                ),
                const Divider(color: AppColors.border, height: 16),
                _buildReceiptRow(
                  'Amount Paid',
                  '₹${(tx?.amount ?? _grossAmount).toStringAsFixed(2)}',
                ),
                const Divider(color: AppColors.border, height: 16),
                _buildReceiptRow(
                  'Coach Payout (90%)',
                  '₹$coachPayout',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Message Coach Now',
            icon: Icons.chat_bubble_rounded,
            onPressed: () {
              Navigator.of(context).pop(_completedTransaction);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Opening secure E2EE chat with '
                    '${widget.trainer.displayName ?? "Coach"}...',
                  ),
                  backgroundColor: AppColors.surfaceElevated,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(_completedTransaction),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

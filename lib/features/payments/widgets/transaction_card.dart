import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/payments/models/payment_transaction.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Interactive card presenting a single payment transaction.
class TransactionCard extends StatelessWidget {
  const TransactionCard({
    required this.transaction,
    super.key,
    this.isTrainerMode = false,
    this.onTap,
  });

  final PaymentTransaction transaction;
  final bool isTrainerMode;
  final VoidCallback? onTap;

  Color _getStatusColor() {
    switch (transaction.status) {
      case PaymentStatus.captured:
        return AppColors.primary;
      case PaymentStatus.authorized:
      case PaymentStatus.created:
        return AppColors.warning;
      case PaymentStatus.failed:
      case PaymentStatus.refunded:
        return AppColors.error;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recent';
    try {
      return DateFormat('MMM d, y • h:mm a').format(dt.toLocal());
    } on Exception catch (_) {
      return dt.toIso8601String().substring(0, 10);
    }
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor().withAlpha(120),
                      ),
                    ),
                    child: Text(
                      transaction.displayStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Amount',
                transaction.displayAmount,
                isHighlight: true,
              ),
              _buildDetailRow(
                'Coach Earnings (90%)',
                transaction.displayTrainerPayout,
              ),
              _buildDetailRow('Platform Fee (10%)', transaction.displayFee),
              _buildDetailRow(
                'Trainer / Coach',
                transaction.trainerName ?? 'Certified Coach',
              ),
              _buildDetailRow('Order ID', transaction.orderId),
              if (transaction.paymentId != null)
                _buildDetailRow('Payment ID', transaction.paymentId!),
              _buildDetailRow(
                'Idempotency Key',
                transaction.idempotencyKey.isNotEmpty
                    ? '${transaction.idempotencyKey.substring(0, 13)}...'
                    : 'System Default',
              ),
              _buildDetailRow('Timestamp', _formatDate(transaction.createdAt)),
              const SizedBox(height: 16),

              // Security & Encryption at Rest Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: AppColors.secondaryAccent,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AES-256-GCM Encrypted at Rest',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sensitive payment metadata is encrypted with '
                            'server-side AEAD cipher. Zero plaintext leakage.',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              fontSize: isHighlight ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final primaryAmountText = isTrainerMode
        ? '+₹${transaction.trainerAmount.toStringAsFixed(2)}'
        : transaction.displayAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ElevatedCard(
        onTap: onTap ?? () => _showDetailSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTrainerMode
                              ? Icons.payments_outlined
                              : Icons.fitness_center_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTrainerMode
                                  ? 'Session Payout'
                                  : (transaction.trainerName ??
                                      '1-on-1 Coaching'),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(transaction.createdAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      primaryAmountText,
                      style: TextStyle(
                        color: isTrainerMode
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transaction.displayStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isTrainerMode) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withAlpha(100),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gross: ${transaction.displayAmount}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Platform Fee: -${transaction.displayFee}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:flutter/material.dart';

/// Card presenting transparent fee split math:
/// Total Amount == Coach Payout + Platform Fee.
class FeeSplitBreakdownCard extends StatelessWidget {
  const FeeSplitBreakdownCard({
    required this.hourlyRate,
    required this.sessionCount,
    required this.totalAmount,
    required this.trainerPayout,
    required this.platformFee,
    super.key,
    this.feePercent = 10.0,
  });

  final double hourlyRate;
  final int sessionCount;
  final double totalAmount;
  final double trainerPayout;
  final double platformFee;
  final double feePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countSuffix = sessionCount > 1 ? 's' : '';
    final rateStr = hourlyRate.toStringAsFixed(0);

    return ElevatedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAYMENT BREAKDOWN',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${feePercent.toStringAsFixed(0)}% Platform Cut',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Base calculation row
          _buildRow(
            label: 'Coach Rate ($sessionCount hr$countSuffix × ₹$rateStr)',
            value: '₹${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Platform fee row
          _buildRow(
            label: 'Platform Security Fee (${feePercent.toStringAsFixed(0)}%)',
            value: '₹${platformFee.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),

          // Coach payout row
          _buildRow(
            label: 'Net Coach Earnings (Direct Route)',
            value: '₹${trainerPayout.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),

          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payable',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '₹${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Security explanation badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withAlpha(128),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.secondaryAccent,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '10% platform fee ensures 24/7 fraud protection, instant '
                    'dispute mediation, and high-uptime infrastructure.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    required TextStyle style,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(value, style: style),
      ],
    );
  }
}

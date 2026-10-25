import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/glowing_progress_bar.dart';
import 'package:fitness_app/features/nutrition/models/daily_macro_summary.dart';
import 'package:flutter/material.dart';

/// Athletic dashboard card displaying today's progress towards calorie and macro goals.
class MacroTargetCard extends StatelessWidget {
  const MacroTargetCard({
    required this.summary,
    this.onTapScanner,
    this.onTapEditTargets,
    super.key,
  });

  final DailyMacroSummary summary;
  final VoidCallback? onTapScanner;
  final VoidCallback? onTapEditTargets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedCard(
      hasGlow: true,
      glowColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x8000E676),
          Color(0x3306B6D4),
          Color(0x1800E676),
          Color(0x22334155),
        ],
      ),
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
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Nutrition',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${summary.loggedMeals} meals logged today',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onTapEditTargets != null)
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Personalize Targets',
                      onPressed: onTapEditTargets,
                    ),
                  if (onTapScanner != null)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                      tooltip: 'Scan Food',
                      onPressed: onTapScanner,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Calorie Progress
          Row(
            children: [
              Expanded(
                child: Text(
                  'Energy: ${summary.totalCalories.toStringAsFixed(0)} / ${summary.targetCalories} kcal',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(summary.caloriesProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          GlowingProgressBar(
            progress: summary.caloriesProgress,
            glowColor: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),

          // Individual Macronutrient Progress Bars
          Row(
            children: [
              Expanded(
                child: _buildMacroMiniColumn(
                  label: 'Protein',
                  currentG: summary.totalProteinG,
                  targetG: summary.targetProteinG,
                  color: AppColors.primary,
                  progress: summary.proteinProgress,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMacroMiniColumn(
                  label: 'Carbs',
                  currentG: summary.totalCarbsG,
                  targetG: summary.targetCarbsG,
                  color: const Color(0xFF06B6D4),
                  progress: summary.carbsProgress,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMacroMiniColumn(
                  label: 'Fat',
                  currentG: summary.totalFatG,
                  targetG: summary.targetFatG,
                  color: const Color(0xFFF59E0B),
                  progress: summary.fatProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMiniColumn({
    required String label,
    required double currentG,
    required int targetG,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${currentG.toStringAsFixed(0)}/${targetG}g',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

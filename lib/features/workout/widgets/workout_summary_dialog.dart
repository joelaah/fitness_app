import 'dart:ui';
import 'package:fitness_app/core/math/fitness_math.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:flutter/material.dart';

/// Modal dialog presented when a user completes a workout session.
/// Displays deterministic athletic metrics: Progressive Overload, Intensity (VLI),
/// and estimated calorie burn alongside total volume and duration.
class WorkoutSummaryDialog extends StatelessWidget {
  const WorkoutSummaryDialog({
    required this.routineName,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.totalReps,
    required this.totalSets,
    this.overload,
    this.intensity,
    this.calorieBurn,
    super.key,
  });

  final String routineName;
  final int durationSeconds;
  final double totalVolumeKg;
  final int totalReps;
  final int totalSets;
  final OverloadResult? overload;
  final IntensityResult? intensity;
  final CalorieBurnResult? calorieBurn;

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '${h}h ${remM}m';
    }
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPR = overload?.isPR ?? false;
    final isPositive = overload?.isPositive ?? false;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ElevatedCard(
        hasGlow: true,
        glowColor: isPR ? AppColors.primary : AppColors.secondaryAccent,
        borderGradient: LinearGradient(
          colors: [
            if (isPR) ...[
              const Color(0xFF00E676),
              const Color(0xFF06B6D4),
            ] else ...[
              const Color(0xFF06B6D4),
              const Color(0xFF3B82F6),
            ],
            const Color(0x22334155),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header icon badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isPR ? AppColors.primary : const Color(0xFF06B6D4))
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPR ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                color: isPR ? AppColors.primary : const Color(0xFF06B6D4),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'WORKOUT COMPLETE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              routineName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),

            // Progressive Overload Highlight Pill
            if (overload != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPositive
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
                      color: isPositive ? AppColors.primary : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PROGRESSION: ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      overload!.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isPositive ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 2x2 Metric Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.fitness_center_rounded,
                    label: 'TOTAL VOLUME',
                    value: '${totalVolumeKg.round()} kg',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.timer_outlined,
                    label: 'DURATION',
                    value: _formatDuration(durationSeconds),
                    color: const Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.local_fire_department_rounded,
                    label: 'EST. CALORIES',
                    value: calorieBurn != null
                        ? '~${calorieBurn!.totalKcal.round()} kcal'
                        : '—',
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.bolt_rounded,
                    label: 'INTENSITY',
                    value: intensity?.label ?? 'Moderate',
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Reusable chip for trainer specialties and categories.
class SpecialtyChip extends StatelessWidget {
  const SpecialtyChip({
    required this.label,
    super.key,
    this.isSelected = false,
    this.isInteractive = false,
    this.onTap,
    this.onDeleted,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final bool isInteractive;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final IconData? icon;

  /// Deterministic tinting matching PulseFit routine covers and exercise badges
  Color _resolveBadgeColor(String specialty) {
    final lower = specialty.toLowerCase().trim();
    if (lower.contains('strength') || lower.contains('powerlifting')) {
      return const Color(0xFFF97316); // Vibrant Orange
    } else if (lower.contains('hypertrophy') ||
        lower.contains('bodybuilding')) {
      return const Color(0xFFA855F7); // Purple
    } else if (lower.contains('hiit') || lower.contains('cardio')) {
      return AppColors.secondaryAccent; // Electric Blue
    } else if (lower.contains('mobility') || lower.contains('yoga')) {
      return const Color(0xFF06B6D4); // Cyan / Teal
    } else if (lower.contains('nutrition') || lower.contains('diet')) {
      return AppColors.primary; // Electric Mint
    } else if (lower.contains('crossfit') || lower.contains('functional')) {
      return const Color(0xFFEC4899); // Pink / Rose
    }
    return AppColors.textSecondary; // Neutral Slate
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isInteractive) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      isSelected ? AppColors.background : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (onDeleted != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDeleted,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isSelected
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Badge / Display Mode
    final color = _resolveBadgeColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

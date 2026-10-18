import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A sleek, hardware-accelerated linear progress bar with subtle neon glowing fill.
class GlowingProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const GlowingProgressBar({
    required this.progress,
    super.key,
    this.height = 4.0,
    this.backgroundColor,
    this.gradient,
    this.glowColor,
    this.borderRadius,
  });

  /// The progress value normalized between 0.0 and 1.0.
  final double progress;

  /// Height of the progress bar track.
  final double height;

  /// Optional background track color.
  final Color? backgroundColor;

  /// Optional custom gradient for the filled portion.
  final Gradient? gradient;

  /// Optional custom glow color for the neon aura.
  final Color? glowColor;

  /// Optional custom border radius. Defaults to half height for a pill shape.
  final BorderRadius? borderRadius;

  @override
  Size get preferredSize => Size.fromHeight(
        (height.isNaN || height.isInfinite || height < 0) ? 0.0 : height,
      );

  @override
  Widget build(BuildContext context) {
    final double safeProgress =
        (progress.isNaN || progress.isInfinite) ? 0.0 : progress;
    final clamped = safeProgress.clamp(0.0, 1.0);
    final double safeHeight =
        (height.isNaN || height.isInfinite || height < 0) ? 0.0 : height;
    final radius = borderRadius ??
        BorderRadius.circular(safeHeight > 0 ? safeHeight / 2 : 0);
    final effectiveGlow = glowColor ?? AppColors.primary;
    final effectiveGradient = gradient ??
        const LinearGradient(
          colors: [
            AppColors.primary,
            Color(0xFF00C853),
            Color(0xFF06B6D4),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        final fillWidth = totalWidth * clamped;

        return Container(
          width: totalWidth,
          height: safeHeight,
          decoration: BoxDecoration(
            color: backgroundColor ??
                AppColors.surfaceElevated.withValues(alpha: 0.5),
            borderRadius: radius,
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: fillWidth,
            height: safeHeight,
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: radius,
              boxShadow: (clamped > 0 && fillWidth > 0 && safeHeight > 0)
                  ? [
                      BoxShadow(
                        color: effectiveGlow.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}

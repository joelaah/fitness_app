import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// An elevated container with delicate athletic neon accent borders, optional
/// ambient glow, and smooth lightweight tactile press feedback.
class ElevatedCard extends StatefulWidget {
  const ElevatedCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderGradient,
    this.borderColor,
    this.borderRadius = 20.0,
    this.hasGlow = false,
    this.glowColor,
    this.enableTactileFeedback = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Delicate neon gradient border. If null and [borderColor] is null, defaults
  /// to a subtle athletic border blending into slate.
  final Gradient? borderGradient;

  /// Optional solid border color. Overrides [borderGradient] if specified.
  final Color? borderColor;

  /// Corner radius of the card. Defaults to 20.0.
  final double borderRadius;

  /// Whether to emit a delicate ambient glow beneath the container.
  final bool hasGlow;

  /// Color of the subtle ambient glow. Defaults to [AppColors.primary].
  final Color? glowColor;

  /// Whether to apply a lightweight scale transform when tapped.
  final bool enableTactileFeedback;

  @override
  State<ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<ElevatedCard> {
  bool _isPressed = false;

  Gradient get _effectiveGradient {
    if (widget.borderGradient != null) return widget.borderGradient!;
    if (widget.hasGlow) {
      final glow = widget.glowColor ?? AppColors.primary;
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glow.withValues(alpha: 0.45),
          glow.withValues(alpha: 0.15),
          AppColors.border,
        ],
      );
    }
    // Default subtle athletic accent gradient
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primary.withValues(alpha: 0.16),
        AppColors.border,
        AppColors.border.withValues(alpha: 0.6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeRadius = (widget.borderRadius.isNaN ||
            widget.borderRadius.isInfinite ||
            widget.borderRadius < 0)
        ? 0.0
        : widget.borderRadius;
    final effectiveRadius = BorderRadius.circular(safeRadius);
    final cardColor =
        widget.color ?? theme.cardTheme.color ?? AppColors.surface;

    final shouldScale = widget.onTap != null && widget.enableTactileFeedback;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: effectiveRadius,
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!)
            : null,
        boxShadow: (widget.hasGlow || widget.glowColor != null)
            ? [
                BoxShadow(
                  color: (widget.glowColor ?? AppColors.primary)
                      .withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: shouldScale
              ? (isHighlighted) {
                  if (mounted && _isPressed != isHighlighted) {
                    setState(() => _isPressed = isHighlighted);
                  }
                }
              : null,
          splashColor: AppColors.primary.withAlpha(25),
          highlightColor: AppColors.primary.withAlpha(10),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    // Apply gradient border painter when no solid borderColor is forced
    if (widget.borderColor == null) {
      cardContent = CustomPaint(
        foregroundPainter: _GradientBorderPainter(
          gradient: _effectiveGradient,
          radius: safeRadius,
          strokeWidth: 1.0,
        ),
        child: cardContent,
      );
    }

    if (shouldScale) {
      return RepaintBoundary(
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.gradient,
    required this.radius,
    this.strokeWidth = 1.0,
  });

  final Gradient gradient;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;
    if (strokeWidth.isNaN || strokeWidth.isInfinite || strokeWidth <= 0) return;
    if (size.width <= strokeWidth || size.height <= strokeWidth) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final deflated = rect.deflate(strokeWidth / 2);
    if (deflated.width <= 0 || deflated.height <= 0) return;
    final safeRadius = (radius.isNaN || radius.isInfinite || radius < 0.0)
        ? 0.0
        : radius.clamp(0.0, deflated.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(
      deflated,
      Radius.circular(safeRadius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

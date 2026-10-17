import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Data model representing an individual concentric volume ring.
class VolumeRingData {
  const VolumeRingData({
    required this.progress, // 0.0 to 1.0+
    required this.startColor,
    required this.endColor,
    this.strokeWidth = 10.0,
    this.label,
  });

  final double progress;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;
  final String? label;
}

/// Cyberpunk-styled animated neon volume ring widget.
class AnimatedNeonVolumeRing extends StatefulWidget {
  const AnimatedNeonVolumeRing({
    required this.rings,
    super.key,
    this.size = 180.0,
    this.centerTitle,
    this.centerSubtitle,
    this.centerIcon,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  final List<VolumeRingData> rings;
  final double size;
  final String? centerTitle;
  final String? centerSubtitle;
  final IconData? centerIcon;
  final Duration animationDuration;

  @override
  State<AnimatedNeonVolumeRing> createState() => _AnimatedNeonVolumeRingState();
}

class _AnimatedNeonVolumeRingState extends State<AnimatedNeonVolumeRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedNeonVolumeRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rings != widget.rings) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _NeonRingsPainter(
                rings: widget.rings,
                animationProgress: _animation.value,
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.centerIcon != null) ...[
                  Icon(
                    widget.centerIcon,
                    color: AppColors.primary,
                    size: widget.size * 0.15,
                  ),
                  const SizedBox(height: 2),
                ],
                if (widget.centerTitle != null)
                  Text(
                    widget.centerTitle!,
                    style: GoogleFonts.poppins(
                      fontSize: widget.size * 0.15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                if (widget.centerSubtitle != null)
                  Text(
                    widget.centerSubtitle!,
                    style: GoogleFonts.inter(
                      fontSize: widget.size * 0.075,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonRingsPainter extends CustomPainter {
  _NeonRingsPainter({
    required this.rings,
    required this.animationProgress,
  });

  final List<VolumeRingData> rings;
  final double animationProgress;

  static const double _startAngle = -math.pi / 2; // 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    double currentRadius = maxRadius - 10.0;

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final strokeW = ring.strokeWidth;
      final sweepAngle = 2 *
          math.pi *
          (ring.progress.clamp(0.0, 1.0)) *
          animationProgress;

      // 1. Draw track background
      final trackPaint = Paint()
        ..color = AppColors.surfaceElevated.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, currentRadius, trackPaint);

      if (sweepAngle > 0.001) {
        final rect = Rect.fromCircle(center: center, radius: currentRadius);

        // 2. Draw outer blur glow with constant sigma
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
          ..color = ring.startColor.withAlpha(100);

        canvas.drawArc(rect, _startAngle, sweepAngle, false, glowPaint);

        // 3. Draw core neon arc
        final coreShader = SweepGradient(
          startAngle: _startAngle,
          endAngle: _startAngle + sweepAngle,
          colors: [ring.startColor, ring.endColor],
          transform: GradientRotation(_startAngle),
        ).createShader(rect);

        final corePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..shader = coreShader;

        canvas.drawArc(rect, _startAngle, sweepAngle, false, corePaint);

        // 4. Luminous tip cap orb
        final tipAngle = _startAngle + sweepAngle;
        final tipCenter = Offset(
          center.dx + currentRadius * math.cos(tipAngle),
          center.dy + currentRadius * math.sin(tipAngle),
        );
        final tipPaint = Paint()
          ..color = ring.endColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tipCenter, strokeW * 0.48, tipPaint);
      }

      currentRadius -= (strokeW + 6.0); // Spacing between rings
    }
  }

  @override
  bool shouldRepaint(covariant _NeonRingsPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.rings != rings;
  }
}

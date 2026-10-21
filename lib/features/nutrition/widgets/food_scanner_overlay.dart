import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Futuristic, athletic scanning laser & radar HUD animation overlay.
/// Active while the meal photo is being uploaded and analyzed by Gemini.
class FoodScannerOverlay extends StatefulWidget {
  const FoodScannerOverlay({
    super.key,
    this.statusText,
    this.isAnalyzing = true,
  });

  final String? statusText;
  final bool isAnalyzing;

  @override
  State<FoodScannerOverlay> createState() => _FoodScannerOverlayState();
}

class _FoodScannerOverlayState extends State<FoodScannerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  late final AnimationController _radarController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  int _telemetryIndex = 0;
  static const _telemetrySteps = [
    'OPTICAL DENSITY RECOGNITION...',
    'DETECTING INGREDIENT VOLUMETRICS...',
    'CROSS-REFERENCING USDA MACRO MATRIX...',
    'COMPUTING ATWATER FACTORS (4P + 4C + 9F)...',
    'CALIBRATING PORTION MASS (GRAMS)...',
  ];

  @override
  void initState() {
    super.initState();

    // Vertical oscillating laser sweep (2.2s period)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOutQuad,
    );

    // Continuous 360-degree radar sweep (3.5s period)
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    // Pulse controller for corner reticle brackets (1.2s period)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _laserController.addListener(_onLaserTick);
  }

  void _onLaserTick() {
    // Cycle telemetry text as laser completes passes
    final progress = _laserController.value;
    final step = (progress * _telemetrySteps.length).floor().clamp(
          0,
          _telemetrySteps.length - 1,
        );
    if (step != _telemetryIndex && mounted) {
      setState(() {
        _telemetryIndex = step;
      });
    }
  }

  @override
  void dispose() {
    _laserController.removeListener(_onLaserTick);
    _laserController.dispose();
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnalyzing) return const SizedBox.shrink();

    final activeText = widget.statusText ?? _telemetrySteps[_telemetryIndex];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Semi-translucent dark sci-fi grid & ambient tint
        Container(
          color: Colors.black.withValues(alpha: 0.35),
        ),

        // 2. Custom Painter rendering Laser, Radar Sweep, and Reticle
        AnimatedBuilder(
          animation: Listenable.merge([
            _laserAnimation,
            _radarController,
            _pulseAnimation,
          ]),
          builder: (context, _) {
            return CustomPaint(
              painter: _FuturisticScannerPainter(
                laserProgress: _laserAnimation.value,
                radarAngle: _radarController.value * 2 * math.pi,
                bracketScale: _pulseAnimation.value,
              ),
            );
          },
        ),

        // 3. Top HUD badge: Scanning indicator
        Positioned(
          top: 20,
          left: 16,
          right: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'PULSEFIT NEURAL VISION',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4. Bottom HUD Diagnostic readout
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        activeText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FuturisticScannerPainter extends CustomPainter {
  const _FuturisticScannerPainter({
    required this.laserProgress,
    required this.radarAngle,
    required this.bracketScale,
  });

  final double laserProgress;
  final double radarAngle;
  final double bracketScale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final minDim = math.min(w, h);

    // ── 1. Corner Reticle Brackets ──
    _drawTargetingReticle(canvas, size, bracketScale);

    // ── 2. Concentric Radar Rings ──
    final ringPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final maxRadius = minDim * 0.38;
    canvas.drawCircle(center, maxRadius * 0.33, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.66, ringPaint);
    canvas.drawCircle(center, maxRadius, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.20)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    // ── 3. Radar Sweep Sector ──
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: radarAngle,
      endAngle: radarAngle + (math.pi / 2.5),
      colors: [
        AppColors.primary.withValues(alpha: 0.0),
        const Color(0xFF06B6D4).withValues(alpha: 0.32),
      ],
    );
    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      sweepRect,
      radarAngle,
      math.pi / 2.5,
      true,
      sweepPaint,
    );

    // ── 4. Vertical Oscillating Laser Beam ──
    final laserY = h * laserProgress;

    // Laser glow aura (broad soft gradient)
    final auraHeight = 50.0;
    final auraRect = Rect.fromLTRB(0, laserY - auraHeight, w, laserY + auraHeight);
    final auraGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.primary.withValues(alpha: 0.0),
        AppColors.primary.withValues(alpha: 0.22),
        AppColors.primary.withValues(alpha: 0.0),
      ],
    );
    final auraPaint = Paint()..shader = auraGradient.createShader(auraRect);
    canvas.drawRect(auraRect, auraPaint);

    // Sharp bright central laser line
    final linePaint = Paint()
      ..color = const Color(0xFFE0FFEA)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawLine(Offset(0, laserY), Offset(w, laserY), linePaint);
  }

  void _drawTargetingReticle(Canvas canvas, Size size, double scale) {
    final margin = 28.0 * scale;
    final length = 32.0;
    final w = size.width;
    final h = size.height;

    final bracketPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-Left
    canvas.drawLine(Offset(margin, margin + length), Offset(margin, margin), bracketPaint);
    canvas.drawLine(Offset(margin, margin), Offset(margin + length, margin), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(w - margin - length, margin), Offset(w - margin, margin), bracketPaint);
    canvas.drawLine(Offset(w - margin, margin), Offset(w - margin, margin + length), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(margin, h - margin - length), Offset(margin, h - margin), bracketPaint);
    canvas.drawLine(Offset(margin, h - margin), Offset(margin + length, h - margin), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(w - margin - length, h - margin), Offset(w - margin, h - margin), bracketPaint);
    canvas.drawLine(Offset(w - margin, h - margin), Offset(w - margin, h - margin - length), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _FuturisticScannerPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress ||
        oldDelegate.radarAngle != radarAngle ||
        oldDelegate.bracketScale != bracketScale;
  }
}

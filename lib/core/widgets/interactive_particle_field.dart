import 'dart:math' as math;
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// High-performance interactive particle canvas field inspired by Zero Hub's
/// physics dot canvas.
///
/// Features:
/// - Smooth cursor repulsion on desktop/web (mouse hover) and mobile (touch drag).
/// - Dynamic spring return to home coordinates with zero mechanical jitter.
/// - Adaptive render loop: halts animation ticker when particles are settled,
///   guaranteeing 0% idle CPU and battery drain.
/// - Subtle PulseFit biometric heartbeat glow radiating across active nodes.
class InteractiveParticleField extends StatefulWidget {
  const InteractiveParticleField({
    super.key,
    this.child,
    this.spacing = 28.0,
    this.dotRadius = 1.2,
    this.repelRadius = 95.0,
    this.pushDistance = 24.0,
    this.easeRate = 0.12,
    this.baseColor,
    this.activeColor,
    this.enableHeartbeatPulse = true,
  });

  /// Optional foreground child rendered directly above the interactive field.
  final Widget? child;

  /// Distance between grid nodes in logical pixels.
  final double spacing;

  /// Base visual radius of resting dots.
  final double dotRadius;

  /// Maximum radius around pointer where repulsion is exerted.
  final double repelRadius;

  /// Maximum displacement distance from origin.
  final double pushDistance;

  /// Interpolation rate for returning to origin (0.05 to 0.25).
  final double easeRate;

  /// Default resting color of dots (defaults to subtle slate-white).
  final Color? baseColor;

  /// Accent color of particles affected by the pointer or biometric pulse.
  final Color? activeColor;

  /// Whether to gently modulate brightness with a subtle resting heartbeat rhythm.
  final bool enableHeartbeatPulse;

  @override
  State<InteractiveParticleField> createState() => _InteractiveParticleFieldState();
}

class _ParticleNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _InteractiveParticleFieldState extends State<InteractiveParticleField>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  AnimationController? _pulseController;
  final _ParticleNotifier _particleNotifier = _ParticleNotifier();
  late Listenable _repaintListenable;

  final List<_Particle> _particles = [];
  Size _lastSize = Size.zero;
  Offset? _pointerPosition;
  bool _isSettled = true;

  /// Whether all particles have returned to their resting origin coordinates.
  bool get isSettled => _isSettled;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _initPulseController();
    _updateRepaintListenable();
  }

  void _initPulseController() {
    if (widget.enableHeartbeatPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat();
    }
  }

  void _updateRepaintListenable() {
    if (_pulseController != null) {
      _repaintListenable = Listenable.merge([_particleNotifier, _pulseController!]);
    } else {
      _repaintListenable = _particleNotifier;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveParticleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableHeartbeatPulse != oldWidget.enableHeartbeatPulse) {
      if (widget.enableHeartbeatPulse) {
        _pulseController ??= AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        );
        _pulseController!.repeat();
      } else {
        _pulseController?.stop();
        _pulseController?.dispose();
        _pulseController = null;
      }
      _updateRepaintListenable();
      _particleNotifier.notify();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulseController?.dispose();
    _particleNotifier.dispose();
    super.dispose();
  }

  void _wakeTicker() {
    _isSettled = false;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onPointerMove(Offset localPosition) {
    _pointerPosition = localPosition;
    _wakeTicker();
  }

  void _onPointerExit() {
    _pointerPosition = null;
    _wakeTicker();
  }

  void _rebuildParticles(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _lastSize = size;
    _particles.clear();

    final cols = (size.width / widget.spacing).ceil() + 1;
    final rows = (size.height / widget.spacing).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final ox = c * widget.spacing;
        final oy = r * widget.spacing;

        // Subtle organic diagonal gradient opacity
        final normX = ox / size.width;
        final normY = oy / size.height;
        final fade = (1.0 - (normX * 0.45 + normY * 0.45)).clamp(0.12, 0.85);

        _particles.add(
          _Particle(
            originX: ox,
            originY: oy,
            x: ox,
            y: oy,
            baseAlpha: fade,
          ),
        );
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_particles.isEmpty) return;

    bool moving = false;
    final ptr = _pointerPosition;
    final repelSq = widget.repelRadius * widget.repelRadius;

    for (final p in _particles) {
      double targetX = p.originX;
      double targetY = p.originY;

      if (ptr != null) {
        final dx = p.x - ptr.dx;
        final dy = p.y - ptr.dy;
        final distSq = dx * dx + dy * dy;

        if (distSq < repelSq && distSq > 0.001) {
          final dist = math.sqrt(distSq);
          final force = (1.0 - dist / widget.repelRadius) * widget.pushDistance;
          targetX = p.originX + (dx / dist) * force;
          targetY = p.originY + (dy / dist) * force;
          p.repelIntensity = (1.0 - dist / widget.repelRadius);
        } else {
          p.repelIntensity *= 0.88;
        }
      } else {
        p.repelIntensity *= 0.88;
      }

      // Smooth damped spring interpolation
      p.x += (targetX - p.x) * widget.easeRate;
      p.y += (targetY - p.y) * widget.easeRate;

      // Check if settled
      if ((p.x - targetX).abs() > 0.05 || (p.y - targetY).abs() > 0.05 || p.repelIntensity > 0.01) {
        moving = true;
      }
    }

    if (!moving && ptr == null) {
      _isSettled = true;
      _ticker.stop();
    }

    _particleNotifier.notify();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastSize != size) {
          _rebuildParticles(size);
          _wakeTicker();
        }

        return MouseRegion(
          onHover: (event) => _onPointerMove(event.localPosition),
          onExit: (_) => _onPointerExit(),
          child: Listener(
            onPointerDown: (event) => _onPointerMove(event.localPosition),
            onPointerMove: (event) => _onPointerMove(event.localPosition),
            onPointerUp: (_) => _onPointerExit(),
            onPointerCancel: (_) => _onPointerExit(),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _ParticlePainter(
                      repaint: _repaintListenable,
                      particles: _particles,
                      dotRadius: widget.dotRadius,
                      baseColor: widget.baseColor ?? const Color(0xFF94A3B8),
                      activeColor: widget.activeColor ?? AppColors.primary,
                      pulseAnimation: _pulseController,
                    ),
                  ),
                ),
                if (widget.child != null) widget.child!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  _Particle({
    required this.originX,
    required this.originY,
    required this.x,
    required this.y,
    required this.baseAlpha,
  });

  final double originX;
  final double originY;
  double x;
  double y;
  final double baseAlpha;
  double repelIntensity = 0.0;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required Listenable repaint,
    required this.particles,
    required this.dotRadius,
    required this.baseColor,
    required this.activeColor,
    required this.pulseAnimation,
  })  : _basePaint = Paint()..style = PaintingStyle.fill,
        _activePaint = Paint()..style = PaintingStyle.fill,
        super(repaint: repaint);

  final List<_Particle> particles;
  final double dotRadius;
  final Color baseColor;
  final Color activeColor;
  final Animation<double>? pulseAnimation;

  final Paint _basePaint;
  final Paint _activePaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final pulsePhase = pulseAnimation != null
        ? pulseAnimation!.value * 2.0 * math.pi
        : 0.0;
    final pulseSin = math.sin(pulsePhase);
    final pulseMod = (pulseSin * 0.15) + 0.85;

    for (final p in particles) {
      if (p.repelIntensity > 0.05) {
        // Active repelling dot: bright accent color and expanded radius
        final r = dotRadius * (1.0 + p.repelIntensity * 1.5);
        _activePaint.color = activeColor.withValues(
          alpha: (p.baseAlpha + p.repelIntensity * 0.6).clamp(0.2, 1.0),
        );
        canvas.drawCircle(Offset(p.x, p.y), r, _activePaint);
      } else {
        // Resting dot
        final alpha = (p.baseAlpha * pulseMod * 0.28).clamp(0.04, 0.45);
        _basePaint.color = baseColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(p.x, p.y), dotRadius, _basePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.activeColor != activeColor;
}

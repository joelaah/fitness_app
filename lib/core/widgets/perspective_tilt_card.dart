import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/spring_motion.dart';
import 'package:flutter/material.dart';

/// Interactive card wrapper providing hardware-accelerated 3D perspective tilt
/// and organic Zero Hub fluid spring physics.
///
/// Features:
/// - Real-time 3D Matrix4 perspective response to cursor hover on web/desktop.
/// - Dynamic vertical card lift (-6px) and subtle scale expansion.
/// - Fluid organic spring release using Zero Hub's `cubic-bezier(0.16, 1, 0.3, 1)`.
/// - Dynamic specular glare radial gradient tracking light reflection.
/// - Smooth hairline neon border illumination on interaction.
class PerspectiveTiltCard extends StatefulWidget {
  const PerspectiveTiltCard({
    required this.child,
    super.key,
    this.onTap,
    this.maxTiltAngle = 0.10, // ~5.7 degrees
    this.scaleFactor = 1.02,
    this.borderRadius = 16.0,
    this.enableGlare = true,
    this.glareIntensity = 0.15,
    this.borderColor,
    this.elevation = 4.0,
    this.liftDistance = 6.0,
    this.glowColor,
    this.springDuration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double maxTiltAngle;
  final double scaleFactor;
  final double borderRadius;
  final bool enableGlare;
  final double glareIntensity;
  final Color? borderColor;
  final double elevation;

  /// Vertical physical lift in pixels applied on hover (default: 6.0).
  final double liftDistance;

  /// Optional custom glow color (defaults to [AppColors.primary]).
  final Color? glowColor;

  /// Duration of the fluid spring release on pointer exit.
  final Duration springDuration;

  @override
  State<PerspectiveTiltCard> createState() => _PerspectiveTiltCardState();
}

class _PerspectiveTiltCardState extends State<PerspectiveTiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _rotXAnimation;
  late Animation<double> _rotYAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _translateYAnimation;

  double _currentRotX = 0.0;
  double _currentRotY = 0.0;
  double _currentScale = 1.0;
  double _currentTranslateY = 0.0;
  double _glareX = 0.0;
  double _glareY = 0.0;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    )..addListener(() {
        setState(() {
          _currentRotX = _rotXAnimation.value;
          _currentRotY = _rotYAnimation.value;
          _currentScale = _scaleAnimation.value;
          _currentTranslateY = _translateYAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPointerMove(Offset localPos, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final normX = ((localPos.dx / size.width) - 0.5) * 2.0; // [-1.0, 1.0]
    final normY = ((localPos.dy / size.height) - 0.5) * 2.0; // [-1.0, 1.0]

    setState(() {
      _isInteracting = true;
      _currentRotX = -normY.clamp(-1.0, 1.0) * widget.maxTiltAngle;
      _currentRotY = normX.clamp(-1.0, 1.0) * widget.maxTiltAngle;
      _currentScale = widget.scaleFactor;
      _currentTranslateY = -widget.liftDistance;
      _glareX = normX;
      _glareY = normY;
    });
  }

  void _onPointerExit() {
    if (!mounted) return;
    _springController.stop();

    _rotXAnimation = Tween<double>(
      begin: _currentRotX,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: ZeroMotionCurves.fluidOut,
    ));
    _rotYAnimation = Tween<double>(
      begin: _currentRotY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: ZeroMotionCurves.fluidOut,
    ));
    _scaleAnimation = Tween<double>(
      begin: _currentScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: ZeroMotionCurves.fluidOut,
    ));
    _translateYAnimation = Tween<double>(
      begin: _currentTranslateY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: ZeroMotionCurves.fluidOut,
    ));

    setState(() {
      _isInteracting = false;
      _glareX = 0.0;
      _glareY = 0.0;
    });

    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // 3D perspective focal depth
          ..translate(0.0, _currentTranslateY, 0.0)
          ..rotateX(_currentRotX)
          ..rotateY(_currentRotY)
          ..scale(_currentScale);

        final activeColor = widget.glowColor ?? AppColors.primary;

        return RepaintBoundary(
          child: MouseRegion(
            onHover: (event) {
              final size = context.size ?? Size.zero;
              _onPointerMove(event.localPosition, size);
            },
            onExit: (_) => _onPointerExit(),
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: widget.onTap,
              onPanStart: (details) {
                final size = context.size ?? Size.zero;
                _onPointerMove(details.localPosition, size);
              },
              onPanUpdate: (details) {
                final size = context.size ?? Size.zero;
                _onPointerMove(details.localPosition, size);
              },
              onPanEnd: (_) => _onPointerExit(),
              onPanCancel: () => _onPointerExit(),
              child: Transform(
                transform: matrix,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: _isInteracting
                          ? activeColor.withValues(alpha: 0.55)
                          : (widget.borderColor ?? Colors.transparent),
                      width: _isInteracting ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isInteracting
                            ? activeColor.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.35),
                        blurRadius: _isInteracting ? 20.0 : widget.elevation,
                        offset: _isInteracting
                            ? Offset(-_glareX * 8.0, -_glareY * 8.0 + 6.0)
                            : const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Stack(
                      children: [
                        widget.child,
                        if (widget.enableGlare && _isInteracting)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(_glareX * 1.2, _glareY * 1.2),
                                    radius: 0.85,
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: (widget.glareIntensity * 0.9).clamp(0.0, 1.0),
                                      ),
                                      activeColor.withValues(
                                        alpha: (widget.glareIntensity * 0.5).clamp(0.0, 1.0),
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.35, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Interactive card wrapper providing hardware-accelerated 3D perspective tilt
/// response to mouse hover on desktop/web and touch gestures on mobile.
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

  @override
  State<PerspectiveTiltCard> createState() => _PerspectiveTiltCardState();
}

class _PerspectiveTiltCardState extends State<PerspectiveTiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late Animation<double> _rotXAnimation;
  late Animation<double> _rotYAnimation;
  late Animation<double> _scaleAnimation;

  double _currentRotX = 0.0;
  double _currentRotY = 0.0;
  double _currentScale = 1.0;
  double _glareX = 0.0;
  double _glareY = 0.0;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        setState(() {
          _currentRotX = _rotXAnimation.value;
          _currentRotY = _rotYAnimation.value;
          _currentScale = _scaleAnimation.value;
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
      curve: Curves.easeOutCubic,
    ));
    _rotYAnimation = Tween<double>(
      begin: _currentRotY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(
      begin: _currentScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutCubic,
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
          ..rotateX(_currentRotX)
          ..rotateY(_currentRotY)
          ..scale(_currentScale);

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
                          ? AppColors.primary.withAlpha(128)
                          : (widget.borderColor ?? Colors.transparent),
                      width: _isInteracting ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isInteracting
                            ? AppColors.primary.withAlpha(45)
                            : Colors.black.withAlpha(90),
                        blurRadius: _isInteracting ? 16.0 : widget.elevation,
                        offset: _isInteracting
                            ? Offset(-_glareX * 6.0, -_glareY * 6.0 + 4.0)
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
                                    center:
                                        Alignment(_glareX * 1.2, _glareY * 1.2),
                                    radius: 0.85,
                                    colors: [
                                      Colors.white.withAlpha(
                                        (widget.glareIntensity * 255).toInt(),
                                      ),
                                      AppColors.primary.withAlpha(
                                        (widget.glareIntensity * 128).toInt(),
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

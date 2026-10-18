import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isDestructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  late final WidgetStatesController _statesController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController();
    _statesController.addListener(_onStatesChanged);
  }

  void _onStatesChanged() {
    final pressed = _statesController.value.contains(WidgetState.pressed);
    if (mounted && _isPressed != pressed) {
      setState(() => _isPressed = pressed);
    }
  }

  @override
  void dispose() {
    _statesController.removeListener(_onStatesChanged);
    _statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: TextButton(
          statesController: _statesController,
          onPressed: widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor:
                widget.isDestructive ? AppColors.error : AppColors.primary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label),
            ],
          ),
        ),
      ),
    );
  }
}

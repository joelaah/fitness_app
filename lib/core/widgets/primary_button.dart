import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.width = double.infinity,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
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
    final theme = Theme.of(context);
    final isInteractive = widget.onPressed != null && !widget.isLoading;

    return SizedBox(
      width: widget.width,
      child: RepaintBoundary(
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isInteractive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _isPressed ? 0.35 : 0.15,
                      ),
                      blurRadius: _isPressed ? 16 : 8,
                      spreadRadius: _isPressed ? 1 : 0,
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            statesController: _statesController,
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: widget.isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(widget.label),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
}

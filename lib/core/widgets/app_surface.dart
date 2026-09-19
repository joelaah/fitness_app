import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.borderRadius = 16.0,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

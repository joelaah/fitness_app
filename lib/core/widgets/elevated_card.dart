import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ElevatedCard extends StatelessWidget {
  const ElevatedCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color ?? theme.cardTheme.color,
      borderRadius: theme.cardTheme.shape is RoundedRectangleBorder
          ? (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius
          : BorderRadius.circular(20),
      elevation: theme.cardTheme.elevation ?? 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withAlpha(25),
        highlightColor: AppColors.primary.withAlpha(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

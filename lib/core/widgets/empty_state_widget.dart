import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
    this.buttonText,
    this.onButtonPressed,
    this.isCard = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool isCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget iconContainer;
    if (isCard) {
      iconContainer = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.08),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 36,
            color: AppColors.primary,
          ),
        ),
      );
    } else {
      iconContainer = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceElevated,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 36,
          color: AppColors.primary,
        ),
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconContainer,
        SizedBox(height: isCard ? 20 : 16),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: 13.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (buttonText != null && onButtonPressed != null) ...[
          SizedBox(height: isCard ? 24 : 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: buttonText!,
                onPressed: onButtonPressed,
              ),
            ),
          ),
        ],
      ],
    );

    if (isCard) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(child: content),
    );
  }
}

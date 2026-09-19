import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:flutter/material.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({
    required this.exercise,
    super.key,
    this.size = 64.0,
    this.borderRadius = 12.0,
  });
  final Exercise exercise;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: exercise.gifUrl.isNotEmpty
          ? Image.asset(
              'assets/${exercise.gifUrl}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return const Center(
      child: Icon(
        Icons.fitness_center,
        color: AppColors.textSecondary,
      ),
    );
  }
}

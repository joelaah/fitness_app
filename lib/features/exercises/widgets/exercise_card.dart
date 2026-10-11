import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:fitness_app/features/exercises/screens/exercise_detail_screen.dart';
import 'package:fitness_app/features/exercises/widgets/exercise_thumbnail.dart';
import 'package:flutter/material.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, super.key});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ElevatedCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<dynamic>(
              builder: (context) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        },
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ExerciseThumbnail(exercise: exercise),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: exercise.subTargetBadgeColor.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: exercise.subTargetBadgeColor.withValues(
                              alpha: 0.3,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          exercise.detailedTarget.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: exercise.subTargetBadgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise.equipment,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

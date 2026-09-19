import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:flutter/material.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({required this.exercise, super.key});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name.toUpperCase()),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise.gifUrl.isNotEmpty)
                  Hero(
                    tag: 'exercise_${exercise.id}',
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/${exercise.gifUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 250,
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.broken_image,
                                size: 50,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      context,
                      Icons.fitness_center,
                      exercise.equipment,
                    ),
                    _buildChip(
                      context,
                      Icons.pie_chart_outline,
                      exercise.primaryMuscleGroup,
                    ),
                    _buildChip(
                      context,
                      Icons.accessibility_new,
                      exercise.detailedTarget,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Instructions',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (exercise.englishSteps.isNotEmpty)
                  ...exercise.englishSteps.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Text(
                    exercise.englishInstructions.isNotEmpty
                        ? exercise.englishInstructions
                        : 'No instructions available.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: PrimaryButton(
              label: 'ADD TO ROUTINE',
              icon: Icons.add,
              onPressed: () {
                // Future integration for adding to a routine
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add to routine coming soon!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/workout/widgets/ai_coach_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onBrowseRoutines,
    this.onOpenAiCoach,
    super.key,
  });
  final VoidCallback onBrowseRoutines;
  final VoidCallback? onOpenAiCoach;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // In the future, this will connect to a Workout/Progress Provider
    // For now, we just show empty states since we haven't started any workouts.
    final hasActiveWorkout = context.watch<WorkoutProvider>().hasActiveWorkout;
    final currentStreak = 0; // TODO: compute from history
    final workoutsThisWeek = 0; // TODO: compute from history

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Good morning,',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to crush it?',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),

              // Progress Overview
              Row(
                children: [
                  Expanded(
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$currentStreak',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Day Streak',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.secondaryAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$workoutsThisWeek',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This Week',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // AI Coach Insights Card
              AiCoachCard(onTap: onOpenAiCoach),

              const SizedBox(height: 28),
              Text(
                "Today's Plan",
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              if (hasActiveWorkout)
                const ElevatedCard(
                  child: Center(child: Text('Active Workout Card')),
                )
              else
                ElevatedCard(
                  padding: EdgeInsets.zero,
                  child: EmptyStateWidget(
                    icon: Icons.calendar_today,
                    title: 'Rest Day',
                    description:
                        'No workout scheduled for today. Take it easy or start a quick routine!',
                    buttonText: 'Browse Routines',
                    onButtonPressed: onBrowseRoutines,
                  ),
                ),

              const SizedBox(height: 32),
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const ElevatedCard(
                padding: EdgeInsets.zero,
                child: EmptyStateWidget(
                  icon: Icons.history,
                  title: 'No Activity Yet',
                  description:
                      'Complete your first workout to see your history here.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

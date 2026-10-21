import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/auth/widgets/guest_expiration_banner.dart';
import 'package:fitness_app/features/nutrition/screens/food_scanner_screen.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/widgets/ai_coach_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    const currentStreak = 0; // TODO: compute from history
    const workoutsThisWeek = 0; // TODO: compute from history

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GuestExpirationBanner(),
              const SizedBox(height: 8),
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

              // Progress Overview (High-Impact Athletic Metric Cards)
              Row(
                children: [
                  Expanded(
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(20),
                      hasGlow: true,
                      glowColor: AppColors.primary,
                      borderGradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x8000E676),
                          Color(0x3300E676),
                          Color(0x1800E676),
                          Color(0x22334155),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$currentStreak',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -1.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Day Streak',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(20),
                      hasGlow: true,
                      glowColor: AppColors.secondaryAccent,
                      borderGradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x803B82F6),
                          Color(0x3306B6D4),
                          Color(0x183B82F6),
                          Color(0x22334155),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryAccent
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.secondaryAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$workoutsThisWeek',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -1.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This Week',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.secondaryAccent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
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

              const SizedBox(height: 16),

              // AI Food & Macro Scanner Card
              ElevatedCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hasGlow: true,
                glowColor: const Color(0xFF06B6D4),
                borderGradient: const LinearGradient(
                  colors: [
                    Color(0x8006B6D4),
                    Color(0x3300E676),
                    Color(0x22334155),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FoodScannerScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF06B6D4),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Food & Macro Scanner',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scan meal photo with Atwater (4P + 4C + 9F) macro tracking',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Text(
                "Today's Plan",
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              if (hasActiveWorkout)
                ElevatedCard(
                  hasGlow: true,
                  glowColor: AppColors.primary,
                  borderGradient: const LinearGradient(
                    colors: [
                      Color(0x9900E676),
                      Color(0x4400C853),
                      Color(0x3306B6D4),
                      Color(0x22334155),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Active Workout Card',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
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

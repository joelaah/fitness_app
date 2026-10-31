import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Card widget displayed on the Home Screen showing latest AI Coach insights.
/// Consumes the shared [AiCoachBloc] to eliminate duplicate startup API calls.
class AiCoachCard extends StatelessWidget {
  const AiCoachCard({this.onTap, super.key});
  final VoidCallback? onTap;

  void _openAiCoach(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AiCoachScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WorkoutProvider>();
    final hasWorkouts = provider.historyRepository.getAll().isNotEmpty;

    AiCoachState? coachState;
    try {
      coachState = context.watch<AiCoachBloc>().state;
    } catch (_) {
      // Gracefully handle contexts where AiCoachBloc is omitted (e.g., unit/widget tests)
    }

    final isLoading = coachState?.isLoading ?? false;
    final recommendation = coachState?.recommendation ??
        RagRecommendationService().getCachedRecommendation();

    String headlineText;
    if (isLoading) {
      headlineText = 'Synthesizing training volume & exercise science...';
    } else if (recommendation != null) {
      final rec = recommendation;
      final nextTitle = rec.nextWorkout.title;
      final topRecommendation = rec.recommendations.isNotEmpty
          ? rec.recommendations.first.description
          : 'Keep up progressive overload!';
      headlineText = '$topRecommendation Next up: $nextTitle.';
    } else if (!hasWorkouts) {
      headlineText =
          'Welcome to PulseFit AI! Ask any fitness question or tap to see your evidence-based starter workout.';
    } else {
      headlineText =
          'Ready for an evidence-based workout analysis? Get your personalized training & recovery plan.';
    }

    return ElevatedCard(
      onTap: () => _openAiCoach(context),
      padding: const EdgeInsets.all(20),
      hasGlow: true,
      glowColor: AppColors.primary,
      borderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x6600E676),
          Color(0x2206B6D4),
          Color(0x22334155),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI COACH',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$headlineText"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openAiCoach(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text(
                'Chat with AI Coach',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

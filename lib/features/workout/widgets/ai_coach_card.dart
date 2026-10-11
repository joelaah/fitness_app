import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/workout/models/ai_recommendation.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/screens/ai_coach_screen.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Card widget displayed on the Home Screen showing latest AI Coach insights.
class AiCoachCard extends StatefulWidget {
  const AiCoachCard({this.onTap, super.key});
  final VoidCallback? onTap;

  @override
  State<AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends State<AiCoachCard> {
  final _service = RagRecommendationService();
  AiRecommendation? _recommendation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCachedOrFetch();
  }

  Future<void> _loadCachedOrFetch() async {
    final cached = _service.getCachedRecommendation();
    if (cached != null) {
      setState(() {
        _recommendation = cached;
      });
      return;
    }

    final provider = context.read<WorkoutProvider>();
    final sessions = provider.historyRepository.getAll();
    if (sessions.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final rec = await _service.getRecommendations(sessions: sessions);
      if (mounted) {
        setState(() {
          _recommendation = rec;
          _isLoading = false;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAiCoach() {
    if (widget.onTap != null) {
      widget.onTap!();
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

    String headlineText;
    if (_isLoading) {
      headlineText = 'Synthesizing training volume & exercise science...';
    } else if (_recommendation != null) {
      final rec = _recommendation!;
      final nextTitle = rec.nextWorkout.title;
      final topRecommendation = rec.recommendations.isNotEmpty
          ? rec.recommendations.first.description
          : 'Keep up progressive overload!';
      headlineText = '$topRecommendation Next up: $nextTitle.';
    } else if (!hasWorkouts) {
      headlineText =
          'Welcome to Aura Fit! Ask any fitness question or tap to see your evidence-based starter workout.';
    } else {
      headlineText =
          'Ready for an evidence-based workout analysis? Get your personalized training & recovery plan.';
    }

    return ElevatedCard(
      onTap: _openAiCoach,
      padding: const EdgeInsets.all(20),
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
              onPressed: _openAiCoach,
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

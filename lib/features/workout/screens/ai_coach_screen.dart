import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class AiCoachScreen extends StatelessWidget {
  const AiCoachScreen({
    super.key,
    this.recommendationService,
    this.bloc,
  });

  final RagRecommendationService? recommendationService;
  final AiCoachBloc? bloc;

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider.value(
        value: bloc!,
        child: const _AiCoachView(),
      );
    }

    try {
      final existing = BlocProvider.of<AiCoachBloc>(context, listen: false);
      return BlocProvider.value(
        value: existing,
        child: const _AiCoachView(),
      );
    } catch (_) {
      return BlocProvider(
        create: (ctx) {
          final workoutProvider = ctx.read<WorkoutProvider>();
          final sessions = workoutProvider.historyRepository.getAll();
          return AiCoachBloc(
            recommendationService: recommendationService,
          )..add(AiCoachRecommendationsRequested(sessions: sessions));
        },
        child: const _AiCoachView(),
      );
    }
  }
}

class _AiCoachView extends StatefulWidget {
  const _AiCoachView();

  @override
  State<_AiCoachView> createState() => _AiCoachViewState();
}

class _AiCoachViewState extends State<_AiCoachView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    'How do I apply progressive overload?',
    'How to prevent knee pain in squats?',
    'Best rest time between heavy sets?',
    'Explain hypertrophy principles',
    'How to fix shoulder impingement on bench?',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage([String? promptText]) {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    context.read<AiCoachBloc>().add(AiCoachMessageSent(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WorkoutProvider>();
    final hasHistory = provider.historyRepository.getAll().isNotEmpty;

    return BlocConsumer<AiCoachBloc, AiCoachState>(
      listener: (context, state) {
        _scrollToBottom();
        if (state.isFailure &&
            state.recommendation != null &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        }
      },
      builder: (context, state) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('AI Coach'),
                ],
              ),
              bottom: const TabBar(
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    text: 'AI Chat',
                  ),
                  Tab(
                    icon: Icon(Icons.insights_rounded, size: 18),
                    text: 'Plan & Insights',
                  ),
                ],
              ),
              actions: [
                if (!state.isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh Insights',
                    onPressed: () {
                      final sessions = context
                          .read<WorkoutProvider>()
                          .historyRepository
                          .getAll();
                      context.read<AiCoachBloc>().add(
                            AiCoachRecommendationsRequested(
                              forceRefresh: true,
                              sessions: sessions,
                            ),
                          );
                    },
                  ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildChatTab(context, theme),
                _buildInsightsTab(context, theme, hasHistory),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTab(BuildContext context, ThemeData theme) {
    return BlocBuilder<AiCoachBloc, AiCoachState>(
      builder: (context, state) {
        final messages = state.messages;
        final isSending = state.isSending;

        return Column(
          children: [
            // Message list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length + (isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isSending && index == messages.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Searching knowledge base & thinking…',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final msg = messages[index];
                  final isUser = msg.isUser;
                  final text = msg.text;
                  final sources = msg.sources;

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: Border.all(
                          color: isUser
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.white10,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Aura Coach',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (msg.sourceType == 'local_fallback') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Server Warming Up',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          if (!isUser) const SizedBox(height: 6),
                          SelectableText(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              height: 1.45,
                            ),
                          ),
                          if (sources.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: sources.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '📚 $s',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick suggestions
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final prompt = _quickPrompts[idx];
                  return ActionChip(
                    label: Text(
                      prompt,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    backgroundColor: AppColors.surfaceElevated,
                    side: const BorderSide(color: Colors.white12),
                    onPressed: () => _sendMessage(prompt),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Chat input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Ask Aura Coach anything...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      onPressed: isSending ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsightsTab(
      BuildContext context, ThemeData theme, bool hasHistory) {
    if (!hasHistory) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateWidget(
            icon: Icons.auto_awesome,
            title: 'No Workout History Yet',
            description:
                'Complete your first workout so the AI Coach can analyze your volume, fatigue, and progression.',
            buttonText: 'Go to AI Chat',
            onButtonPressed: () {
              DefaultTabController.of(context).animateTo(0);
            },
          ),
        ),
      );
    }

    return BlocBuilder<AiCoachBloc, AiCoachState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'Analyzing training volume & research...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (state.isFailure && state.recommendation == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Notice',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'An unexpected error occurred.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      final sessions = context
                          .read<WorkoutProvider>()
                          .historyRepository
                          .getAll();
                      context.read<AiCoachBloc>().add(
                            AiCoachRecommendationsRequested(
                              forceRefresh: true,
                              sessions: sessions,
                            ),
                          );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.recommendation == null) {
          return const SizedBox.shrink();
        }

        final rec = state.recommendation!;
        final summary = rec.summary;

        return RefreshIndicator(
          onRefresh: () async {
            final sessions =
                context.read<WorkoutProvider>().historyRepository.getAll();
            final bloc = context.read<AiCoachBloc>();
            bloc.add(AiCoachRecommendationsRequested(
              forceRefresh: true,
              sessions: sessions,
            ));
            // Wait for non-loading state
            await bloc.stream.firstWhere((s) => !s.isLoading);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evidence-Based Coaching',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Based on your last ${rec.sessionsAnalyzed} sessions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rec.pipelineSource == 'rag')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'RAG Verified',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (rec.pipelineSource == 'local_fallback' ||
                        rec.pipelineSource == 'local')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Server Warming Up',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (rec.cached)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cached',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // 1. Objective Training Summary
                Text('TRAINING SUMMARY', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                ElevatedCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatColumn(
                            label: 'Workouts',
                            value: '${summary.sessionsAnalyzed}',
                          ),
                          _StatColumn(
                            label: 'Volume',
                            value:
                                '${summary.totalVolume.toStringAsFixed(0)} kg',
                          ),
                          _StatColumn(
                            label: 'Sets',
                            value: '${summary.totalSets}',
                          ),
                          _StatColumn(
                            label: 'Reps',
                            value: '${summary.totalReps}',
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white10),

                      // Volume by Muscle Group
                      if (summary.volumeByMuscleGroup.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Volume by Muscle Group:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              summary.volumeByMuscleGroup.entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                '${entry.key}: ${entry.value.toStringAsFixed(0)} kg',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Row(
                        children: [
                          const Icon(Icons.trending_up,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              summary.mostTrainedMuscleGroups.isNotEmpty
                                  ? 'Most trained: ${summary.mostTrainedMuscleGroups.join(', ')}'
                                  : 'Balanced training distribution',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (summary.recentlyUntrainedMuscleGroups.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.battery_charging_full,
                                color: AppColors.secondaryAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recently untrained / rested: ${summary.recentlyUntrainedMuscleGroups.join(', ')}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 2. AI Recommendations
                Text('RECOMMENDATIONS', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                ...rec.recommendations.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: item.priority == 'high'
                                      ? Colors.redAccent.withValues(alpha: 0.2)
                                      : AppColors.primary
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: item.priority == 'high'
                                        ? Colors.redAccent
                                        : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // 3. Recovery
                Text('RECOVERY', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                ...rec.recovery.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.nightlife_rounded,
                              color: AppColors.secondaryAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // 4. Next Workout Suggestion
                Text('SUGGESTED NEXT WORKOUT',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                ElevatedCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fitness_center,
                              color: AppColors.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rec.nextWorkout.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rec.nextWorkout.reason,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (rec.nextWorkout.exercises.isNotEmpty) ...[
                        const Divider(height: 24, color: Colors.white10),
                        Text(
                          'Target Exercises:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rec.nextWorkout.exercises.map((ex) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(color: AppColors.primary)),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyMedium,
                                      children: [
                                        TextSpan(
                                          text: '${ex.name}: ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(
                                          text: ex.reason,
                                          style: const TextStyle(
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 5. Analyze Again Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final sessions = context
                          .read<WorkoutProvider>()
                          .historyRepository
                          .getAll();
                      context.read<AiCoachBloc>().add(
                            AiCoachRecommendationsRequested(
                              forceRefresh: true,
                              sessions: sessions,
                            ),
                          );
                    },
                    icon: const Icon(Icons.bolt, color: Colors.black),
                    label: const Text(
                      'Analyze Again',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

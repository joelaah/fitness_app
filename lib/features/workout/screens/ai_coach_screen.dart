import 'package:fitness_app/core/responsive/app_breakpoints.dart';
import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:fitness_app/features/workout/widgets/ai_quota_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          )
            ..add(const AiCoachQuotaChecked())
            ..add(AiCoachRecommendationsRequested(sessions: sessions));
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

  Future<void> _showUpgradeDialog() async {
    final bloc = context.read<AiCoachBloc>();
    await AiQuotaDialog.show(context);
    if (mounted) {
      bloc.add(const AiCoachQuotaChecked());
    }
  }

  void _sendMessage([String? promptText]) {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty) return;

    final bloc = context.read<AiCoachBloc>();
    if (bloc.state.isQuotaExceeded) {
      _showUpgradeDialog();
      return;
    }

    _textController.clear();
    bloc.add(AiCoachMessageSent(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WorkoutProvider>();
    final hasHistory = provider.historyRepository.getAll().isNotEmpty;
    final isDesktop = AppBreakpoints.isDesktop(context);

    return BlocConsumer<AiCoachBloc, AiCoachState>(
      listenWhen: (previous, current) =>
          (!previous.isQuotaExceeded && current.isQuotaExceeded) ||
          (previous.isFailure != current.isFailure),
      listener: (context, state) {
        _scrollToBottom();
        if (state.isQuotaExceeded) {
          _showUpgradeDialog();
        } else if (state.isFailure &&
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
        if (!isDesktop) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppColors.background,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'AI Coach',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                bottom: const TabBar(
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
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
              body: Builder(
                builder: (tabContext) => TabBarView(
                  children: [
                    _buildChatTab(tabContext, theme),
                    _buildInsightsTab(tabContext, theme, hasHistory),
                  ],
                ),
              ),
            ),
          );
        }

        // Desktop Dual-Column Split-View
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.background,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'AI Coach & RAG Insights',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.splitViewMaxWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildChatTab(context, theme),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    flex: 6,
                    child: _buildInsightsTab(context, theme, hasHistory),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(
      BuildContext context, ThemeData theme, ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'AURA AI COACH',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ONLINE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Evidence-Based Exercise Science Core',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),
          SelectableText(
            msg.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildCapabilityBadge('⚡ Progressive Overload'),
              _buildCapabilityBadge('🔬 Hypertrophy Science'),
              _buildCapabilityBadge('🛡️ Injury Prevention'),
              _buildCapabilityBadge('🔄 Fatigue & Deloads'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(
      BuildContext context, ThemeData theme, ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.of(context).size.width * 0.85)
              .clamp(0.0, 540.0),
        ),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Aura Coach',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (msg.sourceType == 'local_fallback')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Server Warming Up',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              msg.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.48,
                fontSize: 13.5,
              ),
            ),
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.sources.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 11,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: s,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
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
  }

  Widget _buildUserMessage(
      BuildContext context, ThemeData theme, ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.of(context).size.width * 0.85)
              .clamp(0.0, 540.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.16),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SelectableText(
          msg.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            height: 1.45,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChips() {
    final chipHeight =
        (42.0 * MediaQuery.textScalerOf(context).scale(1.0)).clamp(42.0, 72.0);
    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final prompt = _quickPrompts[idx];
          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: AppColors.primary.withValues(alpha: 0.2),
                highlightColor: AppColors.primary.withValues(alpha: 0.1),
                onTap: () => _sendMessage(prompt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatInputDock(bool isSending) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ask Aura Coach anything...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isSending
                      ? const LinearGradient(
                          colors: [
                            AppColors.surfaceElevated,
                            AppColors.surfaceElevated,
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primaryVariant,
                          ],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: isSending
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: IconButton(
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                  onPressed: isSending ? null : () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ),
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
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 12,
                            ),
                          ],
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
                  // If first message and is assistant, render dedicated Welcome Card
                  if (index == 0 && !msg.isUser) {
                    return _buildWelcomeCard(context, theme, msg);
                  }

                  if (!msg.isUser) {
                    return _buildAssistantMessage(context, theme, msg);
                  }

                  return _buildUserMessage(context, theme, msg);
                },
              ),
            ),

            // Quick suggestions
            _buildPromptChips(),
            if (state.isQuotaExceeded)
              Container(
                key: const Key('ai_quota_upgrade_prompt'),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Daily AI limit reached (5/5). Upgrade for unlimited coaching.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      key: const Key('upgrade_prompt_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _showUpgradeDialog(),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Chat input dock
            _buildChatInputDock(isSending),
          ],
        );
      },
    );
  }

  Widget _buildInsightsTab(
      BuildContext context, ThemeData theme, bool hasHistory) {
    if (!hasHistory) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: EmptyStateWidget(
            icon: Icons.auto_awesome,
            title: 'No Workout History Yet',
            description:
                'Complete your first workout so the AI Coach can analyze your volume, fatigue, and progression.',
            buttonText: 'Go to AI Chat',
            isCard: true,
            onButtonPressed: () {
              DefaultTabController.maybeOf(context)?.animateTo(0);
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Evidence-Based Coaching',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Based on your last ${rec.sessionsAnalyzed} sessions',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (rec.pipelineSource == 'rag') ...[
                      const SizedBox(height: 10),
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
                      ),
                    ] else if (rec.pipelineSource == 'local_fallback' ||
                        rec.pipelineSource == 'local') ...[
                      const SizedBox(height: 10),
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
                      ),
                    ] else if (rec.cached) ...[
                      const SizedBox(height: 10),
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
                        children: [
                          Expanded(
                            child: _StatColumn(
                              label: 'Workouts',
                              value: '${summary.sessionsAnalyzed}',
                            ),
                          ),
                          Expanded(
                            child: _StatColumn(
                              label: 'Volume',
                              value:
                                  '${summary.totalVolume.toStringAsFixed(0)} kg',
                            ),
                          ),
                          Expanded(
                            child: _StatColumn(
                              label: 'Sets',
                              value: '${summary.totalSets}',
                            ),
                          ),
                          Expanded(
                            child: _StatColumn(
                              label: 'Reps',
                              value: '${summary.totalReps}',
                            ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.trending_up,
                                color: AppColors.primary, size: 20),
                          ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.battery_charging_full,
                                  color: AppColors.secondaryAccent, size: 20),
                            ),
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
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.fitness_center,
                                color: AppColors.primary, size: 24),
                          ),
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
                                  child: Text.rich(
                                    TextSpan(
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
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.primary,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

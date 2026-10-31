import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/services/ai_quota_service.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';

/// Business Logic Component managing AI recommendations, caching, chat streams,
/// quota enforcement, and graceful fallback states.
class AiCoachBloc extends Bloc<AiCoachEvent, AiCoachState> {
  AiCoachBloc({
    RagRecommendationService? recommendationService,
    AiQuotaService? quotaService,
    AiCoachState? initialState,
  })  : _service = recommendationService ?? RagRecommendationService(),
        _quotaService = quotaService ?? AiQuotaService(),
        super(initialState ?? const AiCoachState()) {
    on<AiCoachRecommendationsRequested>(_onRecommendationsRequested);
    on<AiCoachMessageSent>(_onMessageSent);
    on<AiCoachReset>(_onReset);
    on<AiCoachQuotaChecked>(_onQuotaChecked);
  }

  final RagRecommendationService _service;
  final AiQuotaService _quotaService;

  RagRecommendationService get service => _service;
  AiQuotaService get quotaService => _quotaService;

  Future<void> _onRecommendationsRequested(
    AiCoachRecommendationsRequested event,
    Emitter<AiCoachState> emit,
  ) async {
    emit(state.copyWith(
      status: AiCoachStatus.loading,
      errorMessage: () => null,
    ));

    try {
      final rec = await _service.getRecommendations(
        forceRefresh: event.forceRefresh,
        sessions: event.sessions,
      );
      emit(state.copyWith(
        status: AiCoachStatus.success,
        recommendation: () => rec,
        errorMessage: () => null,
      ));
    } on RateLimitException catch (e) {
      emit(state.copyWith(
        status: AiCoachStatus.failure,
        errorMessage: () => e.message,
      ));
    } on Exception catch (_) {
      emit(state.copyWith(
        status: AiCoachStatus.failure,
        errorMessage: () =>
            'AI Coach is still warming up. Retries were attempted automatically — tap below to try again.',
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AiCoachStatus.failure,
        errorMessage: () =>
            'AI Coach is still warming up. Retries were attempted automatically — tap below to try again.',
      ));
    }
  }

  Future<void> _onMessageSent(
    AiCoachMessageSent event,
    Emitter<AiCoachState> emit,
  ) async {
    final text = event.message.trim();
    if (text.isEmpty || state.isSending) return;

    // Check daily query quota (5 queries/day for free and guest accounts)
    final canQuery = await _quotaService.canMakeQuery();
    if (!canQuery) {
      final remaining = await _quotaService.getRemainingQueries();
      const quotaMsg = ChatMessage(
        role: 'assistant',
        text:
            'Daily AI Coach query limit reached (5/5). Upgrade your account for unlimited queries!',
        sources: [],
        isError: true,
      );
      emit(state.copyWith(
        isQuotaExceeded: true,
        remainingQueries: () => remaining,
        messages: [...state.messages, quotaMsg],
        errorMessage: () =>
            'Daily AI Coach query limit reached (5/5). Upgrade your account for unlimited queries.',
      ));
      return;
    }

    try {
      await _quotaService.consumeQuery();
    } on AiQuotaExceededException catch (e) {
      final remaining = await _quotaService.getRemainingQueries();
      final quotaMsg = ChatMessage(
        role: 'assistant',
        text: e.message,
        sources: [],
        isError: true,
      );
      emit(state.copyWith(
        isQuotaExceeded: true,
        remainingQueries: () => remaining,
        messages: [...state.messages, quotaMsg],
        errorMessage: () => e.message,
      ));
      return;
    }

    final userMessage = ChatMessage(
      role: 'user',
      text: text,
      sources: const [],
    );

    final historyPayload = state.messages
        .where((m) => !m.isError && m.text.trim().isNotEmpty)
        .map((m) => {
              'role': m.role,
              'content': m.text,
            })
        .toList();

    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
    ));

    try {
      final res = await _service.sendChatMessage(text, history: historyPayload);
      final reply =
          res['reply'] as String? ?? 'Keep up your consistent training!';
      final rawSources = res['sources'] as List<dynamic>? ?? [];
      final sources = rawSources.map((s) => s.toString()).toList();
      final sourceType = (res['pipeline_source'] as String?) ?? 'rag';

      // If backend returned a cold-start / server-down local fallback asking user to retry,
      // refund the query so free quota is only consumed for actual answered AI queries.
      if (sourceType == 'local_fallback') {
        await _quotaService.refundQuery();
      }

      final assistantMessage = ChatMessage(
        role: 'assistant',
        text: reply,
        sources: sources,
        sourceType: sourceType,
      );

      final remaining = await _quotaService.getRemainingQueries();
      final canStillQuery = await _quotaService.canMakeQuery();
      emit(state.copyWith(
        messages: [...state.messages, assistantMessage],
        isSending: false,
        remainingQueries: () => remaining,
        isQuotaExceeded: !canStillQuery,
      ));
    } on RateLimitException catch (e) {
      // Refund query so user is not penalized for backend rate limits
      await _quotaService.refundQuery();
      final remaining = await _quotaService.getRemainingQueries();
      final canStillQuery = await _quotaService.canMakeQuery();
      final errorMessage = ChatMessage(
        role: 'assistant',
        text: e.message,
        sources: const [],
        isError: true,
      );
      emit(state.copyWith(
        messages: [...state.messages, errorMessage],
        isSending: false,
        remainingQueries: () => remaining,
        isQuotaExceeded: !canStillQuery,
      ));
    } catch (_) {
      // Refund query on network / socket / timeout / unexpected error
      await _quotaService.refundQuery();
      final remaining = await _quotaService.getRemainingQueries();
      final canStillQuery = await _quotaService.canMakeQuery();
      const errorMessage = ChatMessage(
        role: 'assistant',
        text:
            'AI Coach is still waking up on the server. Please try again in a moment — the server should be ready shortly!',
        sources: [],
        isError: true,
      );
      emit(state.copyWith(
        messages: [...state.messages, errorMessage],
        isSending: false,
        remainingQueries: () => remaining,
        isQuotaExceeded: !canStillQuery,
      ));
    }
  }

  Future<void> _onQuotaChecked(
    AiCoachQuotaChecked event,
    Emitter<AiCoachState> emit,
  ) async {
    final canQuery = await _quotaService.canMakeQuery();
    final remaining = await _quotaService.getRemainingQueries();
    emit(state.copyWith(
      isQuotaExceeded: !canQuery,
      remainingQueries: () => remaining,
    ));
  }

  void _onReset(AiCoachReset event, Emitter<AiCoachState> emit) {
    emit(const AiCoachState());
  }
}

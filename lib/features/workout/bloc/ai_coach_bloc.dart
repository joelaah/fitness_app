import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';

/// Business Logic Component managing AI recommendations, caching, chat streams,
/// and graceful fallback states.
class AiCoachBloc extends Bloc<AiCoachEvent, AiCoachState> {
  AiCoachBloc({
    RagRecommendationService? recommendationService,
    AiCoachState? initialState,
  })  : _service = recommendationService ?? RagRecommendationService(),
        super(initialState ?? const AiCoachState()) {
    on<AiCoachRecommendationsRequested>(_onRecommendationsRequested);
    on<AiCoachMessageSent>(_onMessageSent);
    on<AiCoachReset>(_onReset);
  }

  final RagRecommendationService _service;

  RagRecommendationService get service => _service;

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
    }
  }

  Future<void> _onMessageSent(
    AiCoachMessageSent event,
    Emitter<AiCoachState> emit,
  ) async {
    final text = event.message.trim();
    if (text.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      role: 'user',
      text: text,
      sources: const [],
    );

    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
    ));

    try {
      final res = await _service.sendChatMessage(text);
      final reply =
          res['reply'] as String? ?? 'Keep up your consistent training!';
      final rawSources = res['sources'] as List<dynamic>? ?? [];
      final sources = rawSources.map((s) => s.toString()).toList();
      final sourceType = (res['pipeline_source'] as String?) ?? 'rag';

      final assistantMessage = ChatMessage(
        role: 'assistant',
        text: reply,
        sources: sources,
        sourceType: sourceType,
      );

      emit(state.copyWith(
        messages: [...state.messages, assistantMessage],
        isSending: false,
      ));
    } on RateLimitException catch (e) {
      final errorMessage = ChatMessage(
        role: 'assistant',
        text: e.message,
        sources: const [],
        isError: true,
      );
      emit(state.copyWith(
        messages: [...state.messages, errorMessage],
        isSending: false,
      ));
    } on Exception catch (_) {
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
      ));
    }
  }

  void _onReset(AiCoachReset event, Emitter<AiCoachState> emit) {
    emit(const AiCoachState());
  }
}

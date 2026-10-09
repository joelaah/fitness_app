import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/models/ai_recommendation.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeRagRecommendationService extends RagRecommendationService {
  FakeRagRecommendationService({
    this.recommendationResult,
    this.recommendationException,
    this.chatResult,
    this.chatException,
  }) : super(skipWarmUp: true);

  final AiRecommendation? recommendationResult;
  final Object? recommendationException;
  final Map<String, dynamic>? chatResult;
  final Object? chatException;

  @override
  Future<AiRecommendation> getRecommendations({
    bool forceRefresh = false,
    List<WorkoutSession>? sessions,
  }) async {
    if (recommendationException != null) {
      throw recommendationException!;
    }
    return recommendationResult ??
        RagRecommendationService.buildLocalFallbackRecommendation(sessions);
  }

  @override
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    if (chatException != null) {
      throw chatException!;
    }
    return chatResult ??
        {
          'reply': 'Focus on 1-2 reps in reserve for compound lifts.',
          'sources': ['Schoenfeld 2016 Hypertrophy'],
          'pipeline_source': 'rag',
        };
  }
}

void main() {
  group('AiCoachBloc Unit & State Transition Tests', () {
    test('initial state has correct default values', () {
      final bloc = AiCoachBloc(
        recommendationService: FakeRagRecommendationService(),
      );

      expect(bloc.state.status, AiCoachStatus.initial);
      expect(bloc.state.recommendation, isNull);
      expect(bloc.state.messages.length, 1);
      expect(bloc.state.messages.first.role, 'assistant');
      expect(bloc.state.messages.first.text, contains('Aura AI Coach'));
      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.errorMessage, isNull);

      bloc.close();
    });

    blocTest<AiCoachBloc, AiCoachState>(
      'emits [loading, success] when AiCoachRecommendationsRequested succeeds',
      build: () {
        final mockRec = RagRecommendationService.buildLocalFallbackRecommendation(null);
        return AiCoachBloc(
          recommendationService: FakeRagRecommendationService(
            recommendationResult: mockRec,
          ),
        );
      },
      act: (bloc) => bloc.add(const AiCoachRecommendationsRequested()),
      expect: () => [
        const AiCoachState(
          status: AiCoachStatus.loading,
          recommendation: null,
          errorMessage: null,
        ),
        predicate<AiCoachState>((state) {
          return state.status == AiCoachStatus.success &&
              state.recommendation != null &&
              state.errorMessage == null;
        }),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'emits [loading, failure] with rate limit message when RateLimitException occurs',
      build: () {
        return AiCoachBloc(
          recommendationService: FakeRagRecommendationService(
            recommendationException: const RateLimitException(
              'Rate limit exceeded. Please wait 60 seconds.',
            ),
          ),
        );
      },
      act: (bloc) => bloc.add(const AiCoachRecommendationsRequested()),
      expect: () => [
        const AiCoachState(
          status: AiCoachStatus.loading,
          recommendation: null,
          errorMessage: null,
        ),
        const AiCoachState(
          status: AiCoachStatus.failure,
          recommendation: null,
          errorMessage: 'Rate limit exceeded. Please wait 60 seconds.',
        ),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'emits [loading, failure] with warming-up notice on unexpected exception',
      build: () {
        return AiCoachBloc(
          recommendationService: FakeRagRecommendationService(
            recommendationException: Exception('Render 502 Bad Gateway'),
          ),
        );
      },
      act: (bloc) => bloc.add(const AiCoachRecommendationsRequested()),
      expect: () => [
        const AiCoachState(
          status: AiCoachStatus.loading,
          recommendation: null,
          errorMessage: null,
        ),
        const AiCoachState(
          status: AiCoachStatus.failure,
          recommendation: null,
          errorMessage:
              'AI Coach is still warming up. Retries were attempted automatically — tap below to try again.',
        ),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'ignores empty or whitespace message in AiCoachMessageSent',
      build: () => AiCoachBloc(
        recommendationService: FakeRagRecommendationService(),
      ),
      act: (bloc) {
        bloc.add(const AiCoachMessageSent(''));
        bloc.add(const AiCoachMessageSent('   '));
      },
      expect: () => [],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'emits [isSending: true, isSending: false] with assistant reply and sources on successful chat',
      build: () => AiCoachBloc(
        recommendationService: FakeRagRecommendationService(
          chatResult: {
            'reply': 'Keep 2 reps in reserve for squat progression.',
            'sources': ['Kraemer & Ratamess 2004'],
            'pipeline_source': 'rag',
          },
        ),
      ),
      act: (bloc) => bloc.add(const AiCoachMessageSent('How to progress squats?')),
      expect: () => [
        predicate<AiCoachState>((state) {
          return state.isSending == true &&
              state.messages.length == 2 &&
              state.messages.last.isUser &&
              state.messages.last.text == 'How to progress squats?';
        }),
        predicate<AiCoachState>((state) {
          return state.isSending == false &&
              state.messages.length == 3 &&
              state.messages.last.isAssistant &&
              state.messages.last.text == 'Keep 2 reps in reserve for squat progression.' &&
              state.messages.last.sources.contains('Kraemer & Ratamess 2004') &&
              state.messages.last.sourceType == 'rag';
        }),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'emits assistant error message when RateLimitException thrown during chat',
      build: () => AiCoachBloc(
        recommendationService: FakeRagRecommendationService(
          chatException: const RateLimitException('Chat rate limit reached: 3/min.'),
        ),
      ),
      act: (bloc) => bloc.add(const AiCoachMessageSent('Tell me about warmups')),
      expect: () => [
        predicate<AiCoachState>((state) {
          return state.isSending == true &&
              state.messages.last.isUser &&
              state.messages.last.text == 'Tell me about warmups';
        }),
        predicate<AiCoachState>((state) {
          return state.isSending == false &&
              state.messages.length == 3 &&
              state.messages.last.isAssistant &&
              state.messages.last.isError &&
              state.messages.last.text == 'Chat rate limit reached: 3/min.';
        }),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'emits friendly server waking up message on socket/timeout exception during chat',
      build: () => AiCoachBloc(
        recommendationService: FakeRagRecommendationService(
          chatException: TimeoutException('Connection timed out'),
        ),
      ),
      act: (bloc) => bloc.add(const AiCoachMessageSent('Best recovery protocols?')),
      expect: () => [
        predicate<AiCoachState>((state) {
          return state.isSending == true &&
              state.messages.last.isUser;
        }),
        predicate<AiCoachState>((state) {
          return state.isSending == false &&
              state.messages.last.isAssistant &&
              state.messages.last.isError &&
              state.messages.last.text.contains('AI Coach is still waking up');
        }),
      ],
    );

    blocTest<AiCoachBloc, AiCoachState>(
      'resets state back to initial on AiCoachReset',
      build: () => AiCoachBloc(
        recommendationService: FakeRagRecommendationService(),
        initialState: const AiCoachState(
          status: AiCoachStatus.success,
          isSending: true,
          errorMessage: 'some error',
        ),
      ),
      act: (bloc) => bloc.add(const AiCoachReset()),
      expect: () => [
        const AiCoachState(
          status: AiCoachStatus.initial,
          recommendation: null,
          messages: [AiCoachState.initialChatMessage],
          isSending: false,
          errorMessage: null,
        ),
      ],
    );

    test('AiCoachBloc integrates cleanly with RagRecommendationService via MockClient', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('ping')) {
          return http.Response('{"status": "ok"}', 200);
        }
        if (request.url.path.contains('chat')) {
          return http.Response(
            '{"reply": "Deload every 4-6 weeks.", "sources": ["Periodization 101"], "pipeline_source": "rag"}',
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final service = RagRecommendationService(
        baseUrl: 'https://test-fitness-api.onrender.com',
        client: mockClient,
      );

      final bloc = AiCoachBloc(recommendationService: service);

      bloc.add(const AiCoachMessageSent('When to deload?'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiCoachState>((s) => s.isSending == true && s.messages.last.isUser),
          predicate<AiCoachState>((s) =>
              s.isSending == false &&
              s.messages.last.isAssistant &&
              s.messages.last.text == 'Deload every 4-6 weeks.'),
        ]),
      );

      await bloc.close();
    });

    test('AiCoachState supports optimistic chat appending and source preservation', () {
      final state = const AiCoachState();
      final userMsg = ChatMessage(role: 'user', text: 'How do I squat deeper?');
      final updated = state.copyWith(
        messages: [...state.messages, userMsg],
        isSending: true,
      );

      expect(updated.messages.length, 2);
      expect(updated.messages.last.isUser, isTrue);
      expect(updated.messages.last.text, 'How do I squat deeper?');
      expect(updated.isSending, isTrue);

      final assistantMsg = ChatMessage(
        role: 'assistant',
        text: 'Work on ankle dorsiflexion and hip external rotation.',
        sources: ['Knee Over Toes Guy', 'Squat University'],
      );
      final finalState = updated.copyWith(
        messages: [...updated.messages, assistantMsg],
        isSending: false,
      );

      expect(finalState.messages.length, 3);
      expect(finalState.messages.last.isAssistant, isTrue);
      expect(finalState.messages.last.sources, contains('Squat University'));
      expect(finalState.isSending, isFalse);
    });
  });
}

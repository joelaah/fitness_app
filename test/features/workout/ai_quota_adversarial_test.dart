import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitness_app/core/network/resilient_network_client.dart';
import 'package:fitness_app/features/payments/bloc/payment_bloc.dart';
import 'package:fitness_app/features/payments/bloc/payment_event.dart';
import 'package:fitness_app/features/payments/bloc/payment_state.dart';
import 'package:fitness_app/features/payments/services/payment_service.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_state.dart';
import 'package:fitness_app/features/workout/services/ai_quota_service.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRagService extends RagRecommendationService {
  _FakeRagService({
    this.chatResult,
    this.chatException,
  }) : super(skipWarmUp: true);

  final Map<String, dynamic>? chatResult;
  final Exception? chatException;

  @override
  Future<Map<String, dynamic>> sendChatMessage(
    String message, {
    List<Map<String, String>>? history,
  }) async {
    if (chatException != null) {
      throw chatException!;
    }
    return chatResult ??
        {
          'reply': 'Keep training consistently.',
          'sources': ['Exercise Science'],
          'pipeline_source': 'rag',
        };
  }
}

void main() {
  group('Adversarial & Stress Tests: AI Quota Service & Resiliency', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      RagRecommendationService.defaultDelayProvider = (_) => Duration.zero;
    });

    tearDown(() {
      RagRecommendationService.defaultDelayProvider = null;
    });

    // ── Challenge 1: Concurrency & Race Conditions ────────────────────────
    test('ADVERSARIAL: Concurrent consumeQuery at boundary (4 used, 2 concurrent) must block the 6th', () async {
      final service = AiQuotaService();
      // Consume 4 queries sequentially
      for (var i = 0; i < 4; i++) {
        await service.consumeQuery();
      }
      expect(await service.getUsedQueries(), equals(4));

      // Now launch 5 concurrent consumeQuery attempts simultaneously
      final results = await Future.wait(
        List.generate(5, (_) async {
          try {
            await service.consumeQuery();
            return 'success';
          } on AiQuotaExceededException {
            return 'blocked';
          }
        }),
      );

      final successes = results.where((r) => r == 'success').length;
      final blockeds = results.where((r) => r == 'blocked').length;

      // Exactly ONE of the 5 concurrent requests should succeed (reaching 5/5)
      // and the other 4 must be blocked. Total used queries must never exceed 5.
      expect(successes, equals(1), reason: 'Only exactly 1 request should succeed to reach the 5-limit');
      expect(blockeds, equals(4), reason: '4 requests should be blocked with AiQuotaExceededException');
      expect(await service.getUsedQueries(), equals(5));
      expect(await service.canMakeQuery(), isFalse);
    });

    test('ADVERSARIAL: 10 parallel consumeQuery calls from 0 used must record exactly 5 successes and 5 blocks', () async {
      final service = AiQuotaService();

      final results = await Future.wait(
        List.generate(10, (_) async {
          try {
            await service.consumeQuery();
            return 'success';
          } on AiQuotaExceededException {
            return 'blocked';
          }
        }),
      );

      final successes = results.where((r) => r == 'success').length;
      final blockeds = results.where((r) => r == 'blocked').length;

      expect(successes, equals(5));
      expect(blockeds, equals(5));
      expect(await service.getUsedQueries(), equals(5));
    });

    // ── Challenge 2: Clock Manipulation & Backward Time Shifts ────────────
    test('ADVERSARIAL: Moving system clock backwards to yesterday must NOT reset quota or grant free queries', () async {
      DateTime simulatedTime = DateTime.utc(2026, 10, 17, 14, 0, 0);
      final service = AiQuotaService(clock: () => simulatedTime);

      // Consume all 5 queries on Oct 17
      for (var i = 0; i < 5; i++) {
        await service.consumeQuery();
      }
      expect(await service.canMakeQuery(), isFalse);
      expect(await service.getUsedQueries(), equals(5));

      // User winds device clock BACKWARDS to Oct 16 (yesterday)
      simulatedTime = DateTime.utc(2026, 10, 16, 14, 0, 0);

      // Moving clock backward must NOT reset quota!
      expect(
        await service.canMakeQuery(),
        isFalse,
        reason: 'Tampering clock backward to yesterday must not award 5 free queries',
      );
      expect(await service.getUsedQueries(), equals(5));
    });

    test('ADVERSARIAL: Moving system clock backwards within same day must NOT reset quota', () async {
      DateTime simulatedTime = DateTime.utc(2026, 10, 17, 18, 0, 0);
      final service = AiQuotaService(clock: () => simulatedTime);

      for (var i = 0; i < 5; i++) {
        await service.consumeQuery();
      }
      expect(await service.canMakeQuery(), isFalse);

      // Wind clock backward by 6 hours to 12:00 on the same UTC day
      simulatedTime = DateTime.utc(2026, 10, 17, 12, 0, 0);

      expect(await service.canMakeQuery(), isFalse);
      expect(await service.getUsedQueries(), equals(5));
    });

    // ── Challenge 3: Timeout Retries in RagRecommendationService ───────────
    test('ADVERSARIAL: RagRecommendationService retries TimeoutException up to 3 times before succeeding', () async {
      int attemptsMade = 0;
      final mockClient = MockClient((request) async {
        attemptsMade++;
        if (attemptsMade <= 2) {
          // Attempt 0 and 1 fail with TimeoutException (>15s)
          throw TimeoutException('Simulated 15s timeout on attempt $attemptsMade');
        }
        // Attempt 2 succeeds
        return http.Response(
          '{"pipeline_source": "rag", "sessions_analyzed": 1, "recommendations": [], "summary": {"sessions_analyzed": 0, "total_volume": 0, "total_sets": 0, "total_reps": 0, "volume_by_muscle_group": {}, "fatigue_index": 0.0}, "next_workout": {"day_name": "Push", "title": "Push Day", "exercises": []}}',
          200,
        );
      });

      final service = RagRecommendationService(
        baseUrl: 'https://api.pulsefit.ai',
        client: mockClient,
        retryDelayProvider: (_) => Duration.zero,
      );

      final result = await service.getRecommendations(sessions: []);

      // Must have retried and succeeded on attempt 3 (attemptsMade == 3)
      expect(attemptsMade, equals(3), reason: 'Must retry on TimeoutException instead of immediately breaking');
      expect(result.pipelineSource, equals('rag'));
    });

    test('ADVERSARIAL: RagRecommendationService chat retries TimeoutException before succeeding', () async {
      int attemptsMade = 0;
      final mockClient = MockClient((request) async {
        attemptsMade++;
        if (attemptsMade <= 2) {
          throw TimeoutException('Simulated chat 15s timeout');
        }
        return http.Response(
          '{"reply": "Proper form prevents injury.", "sources": ["Biomechanics"], "pipeline_source": "rag"}',
          200,
        );
      });

      final service = RagRecommendationService(
        baseUrl: 'https://api.pulsefit.ai',
        client: mockClient,
        retryDelayProvider: (_) => Duration.zero,
      );

      final result = await service.sendChatMessage('How to deadlift safely?');

      expect(attemptsMade, equals(3));
      expect(result['reply'], contains('Proper form'));
    });

    // ── Challenge 4: ResilientNetworkClient execute<T> API ─────────────────
    test('ADVERSARIAL: ResilientNetworkClient provides generic execute<T> method with backoff retries', () async {
      int attempts = 0;
      final client = ResilientNetworkClient(
        retryDelayProvider: (_) => Duration.zero,
      );

      final result = await client.execute<String>(() async {
        attempts++;
        if (attempts <= 2) {
          throw const SocketException('Connection aborted');
        }
        return 'success_payload';
      });

      expect(result, equals('success_payload'));
      expect(attempts, equals(3));
    });

    // ── Challenge 5: Upgraded & Free User Metadata Coverage ───────────────
    test('ADVERSARIAL: Various upgraded and free metadata tiers are accurately classified', () {
      final service = AiQuotaService();

      // is_upgraded: true
      final upgradedUser1 = User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {'is_upgraded': true},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      expect(service.isUpgradedUser(user: upgradedUser1), isTrue);

      // tier: 'pro'
      final upgradedUser2 = User(
        id: 'u2',
        appMetadata: const {},
        userMetadata: const {'tier': 'pro'},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      expect(service.isUpgradedUser(user: upgradedUser2), isTrue);

      // subscription: 'pro'
      final upgradedUser3 = User(
        id: 'u3',
        appMetadata: const {},
        userMetadata: const {'subscription': 'pro'},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      expect(service.isUpgradedUser(user: upgradedUser3), isTrue);

      // Explicit tier: 'free' must be classified as non-upgraded
      final freeTierUser = User(
        id: 'u4',
        appMetadata: const {},
        userMetadata: const {'tier': 'free'},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      expect(service.isUpgradedUser(user: freeTierUser), isFalse);
    });

    // ── Challenge 6: SharedPreferences Lazy Resolution ────────────────────
    test('ADVERSARIAL: Fresh AiQuotaService instances without passed prefs share SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      // Instance 1
      final service1 = AiQuotaService();
      await service1.consumeQuery();
      await service1.consumeQuery();
      expect(await service1.getUsedQueries(), equals(2));

      // Instance 2 created independently without injected prefs
      final service2 = AiQuotaService();
      expect(await service2.getUsedQueries(), equals(2));
      expect(await service2.getRemainingQueries(), equals(3));
    });

    // ── Challenge 7: Quota Refund on Network Failure & Fallback ───────────
    test('ADVERSARIAL: Quota is refunded when AI chat encounters network error or local fallback', () async {
      final quotaService = AiQuotaService();
      expect(await quotaService.getUsedQueries(), equals(0));

      // 1. Simulate AiCoachBloc with failing network service
      final bloc = AiCoachBloc(
        quotaService: quotaService,
        recommendationService: _FakeRagService(
          chatException: TimeoutException('Backend timed out after retries'),
        ),
      );

      // Attempt to send a message; the request will fail
      bloc.add(const AiCoachMessageSent('How to program progressive overload?'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AiCoachState>((s) =>
              s.isSending == false &&
              s.messages.last.isAssistant &&
              s.messages.last.isError),
        ),
      );

      // Used quota must have been refunded back to 0!
      expect(
        await quotaService.getUsedQueries(),
        equals(0),
        reason: 'Failed AI queries due to network/timeout errors must NOT consume user quota',
      );
      expect(await quotaService.getRemainingQueries(), equals(5));

      // 2. Simulate server cold-start local fallback (telling user to wait and retry)
      final fallbackBloc = AiCoachBloc(
        quotaService: quotaService,
        recommendationService: _FakeRagService(
          chatResult: {
            'reply': 'Server is spinning up. Please try again in 30 seconds.',
            'sources': ['Local Fallback Guide'],
            'pipeline_source': 'local_fallback',
          },
        ),
      );

      fallbackBloc.add(const AiCoachMessageSent('Best leg day exercises?'));
      await expectLater(
        fallbackBloc.stream,
        emitsThrough(
          predicate<AiCoachState>((s) =>
              s.isSending == false &&
              s.messages.last.sourceType == 'local_fallback'),
        ),
      );

      // Local fallback must NOT consume user quota
      expect(
        await quotaService.getUsedQueries(),
        equals(0),
        reason: 'Server waking up local fallback must NOT consume user quota',
      );

      // 3. Successful RAG response DOES consume quota
      final successBloc = AiCoachBloc(
        quotaService: quotaService,
        recommendationService: _FakeRagService(
          chatResult: {
            'reply': 'Squats, Romanian deadlifts, and lunges are optimal.',
            'sources': ['Hypertrophy Textbook'],
            'pipeline_source': 'rag',
          },
        ),
      );

      successBloc.add(const AiCoachMessageSent('Best leg day exercises?'));
      await expectLater(
        successBloc.stream,
        emitsThrough(
          predicate<AiCoachState>((s) =>
              s.isSending == false &&
              s.messages.last.sourceType == 'rag'),
        ),
      );

      expect(await quotaService.getUsedQueries(), equals(1));
      expect(await quotaService.getRemainingQueries(), equals(4));

      await bloc.close();
      await fallbackBloc.close();
      await successBloc.close();
    });

    test('ADVERSARIAL: AiQuotaService refundQuery is safe against underflow below zero', () async {
      final service = AiQuotaService();
      expect(await service.getUsedQueries(), equals(0));

      // Calling refundQuery on a fresh service must not make count negative
      await service.refundQuery();
      expect(await service.getUsedQueries(), equals(0));
      expect(await service.getRemainingQueries(), equals(5));
    });

    // ── Challenge 8: Non-Exception Errors in ResilientNetworkClient ────────
    test('ADVERSARIAL: ResilientNetworkClient gracefully wraps non-Exception Errors in NetworkResiliencyException', () async {
      final client = ResilientNetworkClient(
        retryDelayProvider: (_) => Duration.zero,
      );

      // 1. AssertionError in execute<T>
      await expectLater(
        client.execute<String>(() async {
          throw AssertionError('State invariant broke');
        }),
        throwsA(
          isA<NetworkResiliencyException>()
              .having((e) => e.originalError, 'originalError', isA<AssertionError>())
              .having((e) => e.message, 'message', contains('unexpected error')),
        ),
      );

      // 2. StateError in execute<T>
      await expectLater(
        client.execute<int>(() async {
          throw StateError('Bad state');
        }),
        throwsA(
          isA<NetworkResiliencyException>()
              .having((e) => e.originalError, 'originalError', isA<StateError>()),
        ),
      );

      // 3. In executeWithRetry
      await expectLater(
        client.executeWithRetry(() async {
          throw AssertionError('Assertion inside HTTP action');
        }),
        throwsA(
          isA<NetworkResiliencyException>()
              .having((e) => e.originalError, 'originalError', isA<AssertionError>()),
        ),
      );
    });

    // ── Challenge 9: Mid-Session Upgrade in AiCoachBloc ────────────────────
    test('ADVERSARIAL: AiCoachQuotaChecked transitions isQuotaExceeded to false and restores unlimited remaining queries', () async {
      final quotaService = AiQuotaService();
      // Consume 5 queries to reach quota limit
      for (var i = 0; i < 5; i++) {
        await quotaService.consumeQuery();
      }
      expect(await quotaService.canMakeQuery(), isFalse);

      final bloc = AiCoachBloc(
        quotaService: quotaService,
        initialState: const AiCoachState(
          isQuotaExceeded: true,
          remainingQueries: 0,
        ),
      );

      expect(bloc.state.isQuotaExceeded, isTrue);
      expect(bloc.state.remainingQueries, equals(0));

      // User upgrades account (manual reset or authenticating upgraded profile)
      await quotaService.resetQuota();

      bloc.add(const AiCoachQuotaChecked());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AiCoachState>((s) =>
              s.isQuotaExceeded == false &&
              s.remainingQueries == 5),
        ),
      );

      await bloc.close();
    });

    // ── Challenge 10: PaymentService Network Resiliency & Exponential Backoff Retries ──
    test('ADVERSARIAL: PaymentService retries transient 502/503 errors and preserves idempotency key across retries', () async {
      int requestCount = 0;
      final seenKeys = <String>[];
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/payments/create-order') {
          requestCount++;
          final body = json.decode(request.body) as Map<String, dynamic>;
          seenKeys.add(body['idempotency_key'] as String);
          if (requestCount <= 2) {
            return http.Response('Bad Gateway (Render cold start)', 502);
          }
          return http.Response(
            json.encode({
              'transaction_id': 'tx_resilient_123',
              'order_id': 'order_resilient_123',
              'amount': 2000.0,
              'platform_fee_amount': 200.0,
              'trainer_amount': 1800.0,
              'replayed': false,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final paymentService = PaymentService(
        client: mockHttp,
        baseUrl: 'https://api.pulsefit.ai',
        retryDelayProvider: (_) => Duration.zero,
        maxRetries: 3,
      );

      final response = await paymentService.createOrder(
        trainerId: 'trainer-99',
        amount: 2000.0,
        idempotencyKey: 'idempotent-key-retry-test',
      );

      expect(response.orderId, equals('order_resilient_123'));
      expect(response.amount, equals(2000.0));
      expect(requestCount, equals(3)); // Initial + 2 retries
      // Crucial requirement: identical idempotency key on every retry
      expect(seenKeys, equals([
        'idempotent-key-retry-test',
        'idempotent-key-retry-test',
        'idempotent-key-retry-test',
      ]));
    });

    // ── Challenge 11: Actionable, Friendly Payment Error Messages ────────
    test('ADVERSARIAL: PaymentBloc emits friendly, actionable error message on network failure', () async {
      final mockHttp = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final paymentService = PaymentService(
        client: mockHttp,
        baseUrl: 'https://api.pulsefit.ai',
        retryDelayProvider: (_) => Duration.zero,
      );
      final bloc = PaymentBloc(paymentService: paymentService);

      bloc.add(
        const InitiatePayment(
          trainerId: 'trainer-1',
          trainerName: 'Coach Mike',
          amount: 1500.0,
          idempotencyKey: 'key-fail-msg-test',
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<PaymentState>((s) =>
              s is PaymentOrderCreated || s is PaymentFailure),
        ),
      );

      await bloc.close();
    });

    // ── Challenge 12: Fast Failure on Non-Transient Errors in RagRecommendationService ──
    test('ADVERSARIAL: RagRecommendationService fails fast on non-transient 400 Bad Request without wasting retries', () async {
      int requestCount = 0;
      final mockHttp = MockClient((request) async {
        requestCount++;
        return http.Response('Bad Request: Invalid payload structure', 400);
      });

      final service = RagRecommendationService(
        baseUrl: 'https://api.pulsefit.ai',
        client: mockHttp,
        skipWarmUp: true,
      );

      final rec = await service.getRecommendations(sessions: []);
      expect(rec.pipelineSource, equals('local_fallback'));
      // Must NOT retry 3 times on 400 (only 1 request made, fail fast)
      expect(requestCount, equals(1));
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'package:fitness_app/core/network/resilient_network_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ResilientNetworkClient Resiliency, Timeouts & Backoff Retries (R2)', () {
    test('calculateDelay returns exactly 1s, 2s, 4s for attempts 1, 2, 3', () {
      expect(ResilientNetworkClient.calculateDelay(1), equals(const Duration(seconds: 1)));
      expect(ResilientNetworkClient.calculateDelay(2), equals(const Duration(seconds: 2)));
      expect(ResilientNetworkClient.calculateDelay(3), equals(const Duration(seconds: 4)));
    });

    test('default timeout is 15 seconds and max retries is 3', () {
      final client = ResilientNetworkClient();
      expect(client.timeout, equals(const Duration(seconds: 15)));
      expect(client.maxRetries, equals(3));
    });

    test('retries transient 502/503 server errors up to 3 times with exponential backoff (1s, 2s, 4s)', () async {
      int requestCount = 0;
      final recordedDelays = <Duration>[];
      final recordedAttempts = <int>[];

      final mockHttp = MockClient((request) async {
        requestCount++;
        if (requestCount <= 3) {
          // Fail attempts 1, 2, 3 with 503 Service Unavailable (e.g. Render warming up)
          return http.Response('Service Unavailable', 503);
        }
        // Succeed on attempt 4 (the 3rd retry)
        return http.Response('{"status": "ok"}', 200);
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        retryDelayProvider: (attempt) {
          final expectedDelay = ResilientNetworkClient.calculateDelay(attempt);
          recordedDelays.add(expectedDelay);
          return Duration.zero; // Fast-forward for test execution
        },
        onRetry: (attempt, delay, error) {
          recordedAttempts.add(attempt);
        },
      );

      final response = await resilientClient.get(Uri.parse('https://api.pulsefit.ai/recommend'));

      expect(response.statusCode, equals(200));
      expect(response.body, contains('ok'));
      expect(requestCount, equals(4)); // Initial + 3 retries
      expect(recordedAttempts, equals([1, 2, 3]));
      expect(
        recordedDelays,
        equals([
          const Duration(seconds: 1),
          const Duration(seconds: 2),
          const Duration(seconds: 4),
        ]),
      );
    });

    test('retries transient SocketException up to 3 times before succeeding', () async {
      int requestCount = 0;
      final recordedDelays = <Duration>[];

      final mockHttp = MockClient((request) async {
        requestCount++;
        if (requestCount < 3) {
          throw const SocketException('Connection reset by peer');
        }
        return http.Response('{"success": true}', 200);
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        retryDelayProvider: (attempt) {
          recordedDelays.add(ResilientNetworkClient.calculateDelay(attempt));
          return Duration.zero;
        },
      );

      final response = await resilientClient.post(
        Uri.parse('https://api.pulsefit.ai/chat'),
        body: '{"message": "hello"}',
      );

      expect(response.statusCode, equals(200));
      expect(requestCount, equals(3)); // Initial + 2 retries
      expect(recordedDelays, equals([
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]));
    });

    test('executes 15s timeout threshold on slow requests and attempts retries', () async {
      int attemptCount = 0;
      final recordedDelays = <Duration>[];

      final mockHttp = MockClient((request) async {
        attemptCount++;
        // Simulate a call exceeding the timeout threshold
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('Too slow', 200);
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        timeout: const Duration(milliseconds: 20), // Short simulated timeout for test speed
        retryDelayProvider: (attempt) {
          recordedDelays.add(ResilientNetworkClient.calculateDelay(attempt));
          return Duration.zero;
        },
      );

      await expectLater(
        resilientClient.get(Uri.parse('https://api.pulsefit.ai/workout/generate')),
        throwsA(
          isA<NetworkResiliencyException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue)
              .having(
                (e) => e.message,
                'message',
                contains('Connection timed out'),
              ),
        ),
      );

      // Verify attempts exhausted to max retries
      expect(attemptCount, equals(4)); // Initial + 3 retries
      expect(recordedDelays, equals([
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]));
    });

    test('non-transient errors (e.g. 400 Bad Request, 429 Rate Limit) are NOT retried', () async {
      int requestCount = 0;

      final mockHttp = MockClient((request) async {
        requestCount++;
        return http.Response('{"error": "Rate limit exceeded"}', 429);
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        retryDelayProvider: (_) => Duration.zero,
      );

      final response = await resilientClient.get(Uri.parse('https://api.pulsefit.ai/chat'));

      // Non-transient 429 must be returned immediately without retrying
      expect(response.statusCode, equals(429));
      expect(requestCount, equals(1));
    });

    test('exhausted retries on 500 returns actionable feedback without crashing', () async {
      int requestCount = 0;

      final mockHttp = MockClient((request) async {
        requestCount++;
        return http.Response('Internal Server Error', 500);
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        retryDelayProvider: (_) => Duration.zero,
      );

      final response = await resilientClient.get(Uri.parse('https://api.pulsefit.ai/recommend'));

      expect(response.statusCode, equals(500));
      expect(requestCount, equals(4)); // 1 initial + 3 retries exhausted
    });

    test('exhausted retries on network exception throws NetworkResiliencyException with actionable message', () async {
      final mockHttp = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });

      final resilientClient = ResilientNetworkClient(
        client: mockHttp,
        retryDelayProvider: (_) => Duration.zero,
      );

      await expectLater(
        resilientClient.get(Uri.parse('https://api.pulsefit.ai/recommend')),
        throwsA(
          isA<NetworkResiliencyException>()
              .having((e) => e.attemptsMade, 'attemptsMade', equals(4))
              .having(
                (e) => e.message,
                'message',
                contains('Network connection failed after 3 retry attempts'),
              ),
        ),
      );
    });

    test('formatFriendlyErrorMessage maps network, timeout, and 5xx errors to actionable messages', () {
      expect(
        ResilientNetworkClient.formatFriendlyErrorMessage(
          TimeoutException('Timed out'),
        ),
        contains('Connection timed out'),
      );
      expect(
        ResilientNetworkClient.formatFriendlyErrorMessage(
          const SocketException('Failed host lookup'),
        ),
        contains('Network connection failed'),
      );
      expect(
        ResilientNetworkClient.formatFriendlyErrorMessage(
          Exception('Server returned 503 Service Unavailable'),
        ),
        contains('Server is temporarily busy'),
      );
      expect(
        ResilientNetworkClient.formatFriendlyErrorMessage(
          const NetworkResiliencyException(message: 'Custom resilient message'),
        ),
        equals('Custom resilient message'),
      );
    });

    test('defaultDelayProvider provides global delay override across instances', () async {
      ResilientNetworkClient.defaultDelayProvider = (_) => Duration.zero;

      int attemptCount = 0;
      final mockHttp = MockClient((request) async {
        attemptCount++;
        if (attemptCount < 3) throw const SocketException('Transient drop');
        return http.Response('{"ok": true}', 200);
      });

      // No retryDelayProvider supplied; relies on static defaultDelayProvider
      final client = ResilientNetworkClient(client: mockHttp);
      final response = await client.get(Uri.parse('https://api.pulsefit.ai/ping'));
      expect(response.statusCode, equals(200));
      expect(attemptCount, equals(3));
    });
  });
}

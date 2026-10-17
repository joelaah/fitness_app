import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exception representing an exhausted retry attempt or unrecoverable network failure.
class NetworkResiliencyException implements Exception {
  const NetworkResiliencyException({
    required this.message,
    this.originalError,
    this.statusCode,
    this.attemptsMade = 0,
    this.isTimeout = false,
  });

  final String message;
  final Object? originalError;
  final int? statusCode;
  final int attemptsMade;
  final bool isTimeout;

  @override
  String toString() => message;
}

/// A network client wrapper providing production-grade resiliency:
/// - 15-second timeout on requests.
/// - Exponential backoff retries (up to 3 retries: 1s, 2s, 4s delays).
/// - Detection of transient network/server failures (5xx status codes, SocketException, TimeoutException).
/// - Graceful actionable error feedback on exhausted retries or timeouts.
class ResilientNetworkClient {
  ResilientNetworkClient({
    http.Client? client,
    this.timeout = defaultTimeout,
    this.maxRetries = defaultMaxRetries,
    this.retryDelayProvider,
    this.onRetry,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Default request timeout: 15 seconds
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Default maximum retries: 3 attempts
  static const int defaultMaxRetries = 3;

  /// Global default delay provider for fast test execution across instances.
  static Duration Function(int retryAttempt)? defaultDelayProvider =
      (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))
          ? (_) => Duration.zero
          : null;

  /// Timeout threshold for requests
  final Duration timeout;

  /// Maximum retry attempts
  final int maxRetries;

  /// Custom retry delay provider for testability or specific backoff strategies.
  /// If null, [calculateDelay] is used.
  final Duration Function(int retryAttempt)? retryDelayProvider;

  /// Optional hook triggered before each retry attempt (useful for telemetry and testing).
  final void Function(int attempt, Duration delay, Object error)? onRetry;

  /// Calculates exponential backoff delay:
  /// - Attempt 1: 1 second
  /// - Attempt 2: 2 seconds
  /// - Attempt 3: 4 seconds
  static Duration calculateDelay(int attempt) {
    switch (attempt) {
      case 1:
        return const Duration(seconds: 1);
      case 2:
        return const Duration(seconds: 2);
      case 3:
        return const Duration(seconds: 4);
      default:
        return Duration(seconds: 1 << (attempt - 1));
    }
  }

  /// Determines whether an error is transient and eligible for retry.
  static bool isTransientError(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    return false;
  }

  /// Determines whether an HTTP status code represents a transient server failure.
  static bool isTransientStatusCode(int statusCode) {
    return statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  /// Execute a GET request with timeout and exponential backoff retries.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? requestTimeout,
    int? customMaxRetries,
  }) {
    return executeWithRetry(
      () => _client.get(url, headers: headers),
      requestTimeout: requestTimeout,
      customMaxRetries: customMaxRetries,
    );
  }

  /// Execute a POST request with timeout and exponential backoff retries.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? requestTimeout,
    int? customMaxRetries,
  }) {
    return executeWithRetry(
      () => _client.post(url, headers: headers, body: body, encoding: encoding),
      requestTimeout: requestTimeout,
      customMaxRetries: customMaxRetries,
    );
  }

  /// Execute an arbitrary HTTP operation with 15-second timeout and 3x exponential backoff retries.
  Future<http.Response> executeWithRetry(
    Future<http.Response> Function() action, {
    Duration? requestTimeout,
    int? customMaxRetries,
  }) async {
    final effectiveTimeout = requestTimeout ?? timeout;
    final effectiveMaxRetries = customMaxRetries ?? maxRetries;

    Object? lastError;
    int? lastStatusCode;
    int attemptsMade = 0;

    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
      attemptsMade = attempt + 1;

      if (attempt > 0) {
        final delay = retryDelayProvider != null
            ? retryDelayProvider!(attempt)
            : (defaultDelayProvider != null
                ? defaultDelayProvider!(attempt)
                : calculateDelay(attempt));

        onRetry?.call(attempt, delay, lastError ?? Exception('HTTP $lastStatusCode'));
        debugPrint(
          'ResilientNetworkClient: Retrying after transient error ($lastError / HTTP $lastStatusCode). '
          'Attempt $attempt of $effectiveMaxRetries. Delay: ${delay.inMilliseconds}ms',
        );

        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }

      try {
        final response = await action().timeout(effectiveTimeout);

        if (isTransientStatusCode(response.statusCode)) {
          lastStatusCode = response.statusCode;
          lastError = Exception('Server returned transient status HTTP ${response.statusCode}');
          if (attempt < effectiveMaxRetries) {
            continue;
          }
          // Exhausted retries on 5xx
          return response;
        }

        // Success or non-transient status code (2xx, 4xx)
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('ResilientNetworkClient: Attempt $attempt timed out after ${effectiveTimeout.inSeconds}s');
        if (attempt < effectiveMaxRetries) {
          continue;
        }
        throw NetworkResiliencyException(
          message: 'Connection timed out after ${effectiveTimeout.inSeconds} seconds. '
              'Automatic retries were exhausted. Please check your connection and try again.',
          originalError: e,
          attemptsMade: attemptsMade,
          isTimeout: true,
        );
      } catch (e) {
        if (!isTransientError(e)) {
          if (e is Error) {
            throw NetworkResiliencyException(
              message: 'Network operation encountered an unexpected error: $e.',
              originalError: e,
              attemptsMade: attemptsMade,
            );
          }
          // Non-transient client/format error: do not retry
          rethrow;
        }
        lastError = e;
        debugPrint('ResilientNetworkClient: Attempt $attempt transient network error: $e');
        if (attempt < effectiveMaxRetries) {
          continue;
        }
        throw NetworkResiliencyException(
          message: 'Network connection failed after $effectiveMaxRetries retry attempts. '
              'Please check your internet connection and try again.',
          originalError: e,
          attemptsMade: attemptsMade,
          isTimeout: false,
        );
      }
    }

    throw NetworkResiliencyException(
      message: 'Network request failed after $attemptsMade attempts. Please try again.',
      originalError: lastError,
      statusCode: lastStatusCode,
      attemptsMade: attemptsMade,
    );
  }

  /// Alias for [executeWithRetry] to execute an HTTP request with retry logic
  Future<http.Response> executeHttp(
    Future<http.Response> Function() action, {
    Duration? requestTimeout,
    int? customMaxRetries,
  }) =>
      executeWithRetry(
        action,
        requestTimeout: requestTimeout,
        customMaxRetries: customMaxRetries,
      );

  /// Execute an arbitrary asynchronous operation with 15-second timeout and 3x exponential backoff retries.
  Future<T> execute<T>(
    Future<T> Function() action, {
    Duration? requestTimeout,
    int? customMaxRetries,
    bool Function(Object error)? isTransient,
  }) async {
    final effectiveTimeout = requestTimeout ?? timeout;
    final effectiveMaxRetries = customMaxRetries ?? maxRetries;

    Object? lastError;
    int attemptsMade = 0;

    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
      attemptsMade = attempt + 1;

      if (attempt > 0) {
        final delay = retryDelayProvider != null
            ? retryDelayProvider!(attempt)
            : (defaultDelayProvider != null
                ? defaultDelayProvider!(attempt)
                : calculateDelay(attempt));

        onRetry?.call(attempt, delay, lastError ?? Exception('Attempt $attempt failed'));
        debugPrint(
          'ResilientNetworkClient: Retrying after transient error ($lastError). '
          'Attempt $attempt of $effectiveMaxRetries. Delay: ${delay.inMilliseconds}ms',
        );

        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }

      try {
        return await action().timeout(effectiveTimeout);
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('ResilientNetworkClient: Attempt $attempt timed out after ${effectiveTimeout.inSeconds}s');
        if (attempt < effectiveMaxRetries) {
          continue;
        }
        throw NetworkResiliencyException(
          message: 'Connection timed out after ${effectiveTimeout.inSeconds} seconds. '
              'Automatic retries were exhausted. Please check your connection and try again.',
          originalError: e,
          attemptsMade: attemptsMade,
          isTimeout: true,
        );
      } catch (e) {
        final transient = isTransient != null ? isTransient(e) : isTransientError(e);
        if (!transient) {
          if (e is Error) {
            throw NetworkResiliencyException(
              message: 'Operation encountered an unexpected error: $e.',
              originalError: e,
              attemptsMade: attemptsMade,
            );
          }
          rethrow;
        }
        lastError = e;
        debugPrint('ResilientNetworkClient: Attempt $attempt transient error: $e');
        if (attempt < effectiveMaxRetries) {
          continue;
        }
        throw NetworkResiliencyException(
          message: 'Network connection failed after $effectiveMaxRetries retry attempts. '
              'Please check your internet connection and try again.',
          originalError: e,
          attemptsMade: attemptsMade,
          isTimeout: false,
        );
      }
    }

    throw NetworkResiliencyException(
      message: 'Operation failed after $attemptsMade attempts. Please try again.',
      originalError: lastError,
      attemptsMade: attemptsMade,
    );
  }

  /// Returns an actionable, user-friendly error message for network/server failures.
  static String formatFriendlyErrorMessage(
    Object error, {
    String fallback =
        'Server is temporarily busy. Please try again in a few moments.',
  }) {
    if (error is NetworkResiliencyException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return 'Connection timed out. Automatic retries were exhausted. Please check your internet connection and try again.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused') ||
        raw.contains('ClientException')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }
    if (raw.contains('TimeoutException')) {
      return 'Connection timed out. Automatic retries were exhausted. Please check your internet connection and try again.';
    }
    if (raw.contains('500') ||
        raw.contains('502') ||
        raw.contains('503') ||
        raw.contains('504')) {
      return 'Server is temporarily busy. Please try again in a few moments.';
    }
    if (raw.isNotEmpty && !raw.contains('Instance of')) {
      return raw;
    }
    return fallback;
  }

  void close() {
    _client.close();
  }
}

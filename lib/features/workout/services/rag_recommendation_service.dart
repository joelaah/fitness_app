import 'dart:async';
import 'dart:convert';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/features/workout/models/ai_recommendation.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for communicating with the RAG recommendation backend.
/// Handles authentication, payload serialization, error states, local caching,
/// client-side rate limiting, and input sanitization.
///
/// Includes automatic warm-up pinging and retry logic to handle Render.com
/// free-tier cold starts without requiring the user to send duplicate requests.
class RagRecommendationService {
  RagRecommendationService({
    String? baseUrl,
    SharedPreferences? prefs,
  })  : _baseUrl = baseUrl ?? _defaultBaseUrl(),
        _prefs = prefs {
    // Fire-and-forget warm-up ping so the server starts waking immediately
    warmUp();
  }

  final String _baseUrl;
  final SharedPreferences? _prefs;

  static const _cacheKey = 'cached_ai_recommendation';

  /// Maximum number of automatic retries for cold-start failures
  static const _maxRetries = 2;

  /// Whether a warm-up ping is already in-flight (avoids duplicate pings)
  static bool _warmUpInFlight = false;

  // ── Client-side rate limiting ──────────────────────────────────────
  /// Minimum interval between consecutive chat requests
  static const _chatCooldown = Duration(seconds: 3);

  /// Maximum number of chat requests allowed within [_chatWindowDuration]
  static const _chatWindowMaxRequests = 15;
  static const _chatWindowDuration = Duration(minutes: 5);

  /// Minimum interval between consecutive recommendation requests
  static const _recommendCooldown = Duration(seconds: 10);

  /// Maximum chat message length (characters)
  static const _maxMessageLength = 500;

  /// Timestamps of recent chat requests for sliding-window rate limiting
  final List<DateTime> _chatTimestamps = [];

  /// Last time a chat request was sent
  DateTime? _lastChatRequestTime;

  /// Last time a recommend request was sent
  DateTime? _lastRecommendRequestTime;

  // ── URL resolution ─────────────────────────────────────────────────

  /// Resolve the API base URL.
  ///
  /// For release builds: supply via --dart-define=RAG_API_URL=https://your-api.onrender.com
  /// For debug builds: automatically uses localhost (Android emulator-aware).
  static String _defaultBaseUrl() {
    const definedUrl = String.fromEnvironment('RAG_API_URL');
    if (definedUrl.isNotEmpty) return definedUrl;

    // Default live public cloud API URL
    return 'https://fitness-rag-api.onrender.com';
  }

  // ── Auth ────────────────────────────────────────────────────────────

  /// Get the current authorization token from Supabase or fallback dev token
  String _getAuthToken() {
    if (SupabaseConfig.isInitialized) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.accessToken.isNotEmpty) {
          return session.accessToken;
        }
      } catch (_) {
        // Supabase not initialized or running in standalone mode
      }
    }
    return 'dev-user-local';
  }

  // ── Warm-up ────────────────────────────────────────────────────────

  /// Send a lightweight GET to the API root to wake up the Render.com server.
  /// This is fire-and-forget; failures are silently ignored.
  Future<void> warmUp() async {
    if (_warmUpInFlight) return;
    _warmUpInFlight = true;
    try {
      await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 10));
      debugPrint('RAG API warm-up ping succeeded');
    } catch (e) {
      debugPrint('RAG API warm-up ping (expected during cold start): $e');
    } finally {
      _warmUpInFlight = false;
    }
  }

  // ── Input validation & rate limiting helpers ───────────────────────

  /// Sanitize user input: trim, enforce length limit, strip control chars.
  String _sanitizeMessage(String raw) {
    // Trim whitespace
    var cleaned = raw.trim();
    // Remove ASCII control characters (except newline/tab)
    cleaned = cleaned.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );
    // Enforce maximum length
    if (cleaned.length > _maxMessageLength) {
      cleaned = cleaned.substring(0, _maxMessageLength);
    }
    return cleaned;
  }

  /// Check whether a chat request is allowed under rate limits.
  /// Throws [RateLimitException] if not.
  void _enforceChatRateLimit() {
    final now = DateTime.now();

    // 1. Per-request cooldown
    if (_lastChatRequestTime != null) {
      final elapsed = now.difference(_lastChatRequestTime!);
      if (elapsed < _chatCooldown) {
        final waitSec = (_chatCooldown - elapsed).inSeconds + 1;
        throw RateLimitException(
          'Please wait $waitSec seconds before sending another message.',
        );
      }
    }

    // 2. Sliding-window limit
    _chatTimestamps.removeWhere(
      (ts) => now.difference(ts) > _chatWindowDuration,
    );
    if (_chatTimestamps.length >= _chatWindowMaxRequests) {
      throw RateLimitException(
        'You\'ve sent many messages recently. Please wait a few minutes before continuing.',
      );
    }
  }

  /// Check whether a recommend request is allowed under rate limits.
  void _enforceRecommendRateLimit() {
    final now = DateTime.now();
    if (_lastRecommendRequestTime != null) {
      final elapsed = now.difference(_lastRecommendRequestTime!);
      if (elapsed < _recommendCooldown) {
        final waitSec = (_recommendCooldown - elapsed).inSeconds + 1;
        throw RateLimitException(
          'Insights were refreshed recently. Please wait $waitSec seconds.',
        );
      }
    }
  }

  // ── Cache ──────────────────────────────────────────────────────────

  /// Load cached recommendation from local storage if available
  AiRecommendation? getCachedRecommendation() {
    if (_prefs == null) return null;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return AiRecommendation.fromJson(data);
    } catch (e) {
      debugPrint('Error decoding cached recommendation: $e');
      return null;
    }
  }

  // ── Recommendations endpoint ───────────────────────────────────────

  /// Fetch recommendations from the FastAPI backend.
  /// If [forceRefresh] is true, bypasses server cache and regenerates fresh guidance.
  ///
  /// Automatically retries up to [_maxRetries] times on timeout / server errors
  /// to handle Render.com cold-start latency transparently.
  Future<AiRecommendation> getRecommendations({
    bool forceRefresh = false,
    List<WorkoutSession>? sessions,
  }) async {
    // Rate limit check
    _enforceRecommendRateLimit();

    final token = _getAuthToken();
    final url = Uri.parse('$_baseUrl/recommend');

    // Build payload including recent local sessions as backup/context
    final Map<String, dynamic> body = {
      'force_refresh': forceRefresh,
    };

    if (sessions != null && sessions.isNotEmpty) {
      body['recent_sessions'] = sessions.take(10).map((s) {
        return {
          'id': s.id,
          'routine_name': s.routineName,
          'started_at': s.startTime.toIso8601String(),
          'completed_at': s.endTime?.toIso8601String(),
          'duration_seconds': s.durationSeconds,
          'total_volume': s.totalVolume,
          'total_reps': s.totalReps,
          'exercises': s.exercises.where((e) => !e.isSkipped).map((e) {
            return {
              'exercise_id': e.exerciseId,
              'primary_muscle_group': 'General',
              'sets': e.sets.where((st) => st.isCompleted).map((st) {
                return {
                  'completed_reps': st.completedReps ?? st.targetReps,
                  'completed_weight':
                      st.completedWeight ?? st.targetWeight,
                  'is_completed': true,
                };
              }).toList(),
            };
          }).toList(),
        };
      }).toList();
    }

    _lastRecommendRequestTime = DateTime.now();

    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // Exponential backoff: 2s, 4s between retries
          final delay = Duration(seconds: 2 * attempt);
          debugPrint(
            'RAG recommend retry $attempt after ${delay.inSeconds}s',
          );
          await Future<void>.delayed(delay);
        }

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          final data =
              jsonDecode(response.body) as Map<String, dynamic>;
          final recommendation = AiRecommendation.fromJson(data);

          // Cache recommendation locally
          if (_prefs != null) {
            await _prefs.setString(_cacheKey, response.body);
          }

          return recommendation;
        } else if (response.statusCode == 429) {
          // Server-side rate limit — do NOT retry
          throw RateLimitException(
            'The AI server is busy. Please try again in a minute.',
          );
        } else if (response.statusCode >= 500 &&
            attempt < _maxRetries) {
          lastError = Exception(
            'Server returned ${response.statusCode}',
          );
          continue;
        } else {
          throw Exception(
            'Server returned ${response.statusCode}',
          );
        }
      } on RateLimitException {
        rethrow; // Never retry rate-limit errors
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('RAG recommend attempt $attempt timed out');
        if (attempt >= _maxRetries) break;
      } catch (e) {
        if (e is Exception) lastError = e;
        debugPrint('RAG API Error (attempt $attempt): $e');
        if (attempt >= _maxRetries) break;
      }
    }

    // All retries exhausted — fallback to cache or rethrow
    debugPrint('RAG API: all retries exhausted');
    final cached = getCachedRecommendation();
    if (cached != null) {
      return cached;
    }
    throw lastError ?? Exception('Failed to fetch recommendations');
  }

  // ── Chat endpoint ──────────────────────────────────────────────────

  /// Send a question to the conversational RAG chat endpoint.
  ///
  /// Applies client-side rate limiting, input sanitization, and
  /// automatically retries up to [_maxRetries] times on timeout / server
  /// errors to handle Render.com cold-start latency transparently.
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    // 1. Sanitize input
    final sanitized = _sanitizeMessage(message);
    if (sanitized.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    // 2. Rate limit check
    _enforceChatRateLimit();

    final url = Uri.parse('$_baseUrl/chat');
    final token = _getAuthToken();

    // 3. Record timestamp for rate-limiting
    final now = DateTime.now();
    _lastChatRequestTime = now;
    _chatTimestamps.add(now);

    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = Duration(seconds: 2 * attempt);
          debugPrint(
            'RAG chat retry $attempt after ${delay.inSeconds}s',
          );
          await Future<void>.delayed(delay);
        }

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'message': sanitized}),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else if (response.statusCode == 429) {
          throw RateLimitException(
            'The AI server is busy. Please try again in a minute.',
          );
        } else if (response.statusCode >= 500 &&
            attempt < _maxRetries) {
          lastError = Exception(
            'Chat server error ${response.statusCode}',
          );
          continue;
        } else {
          throw Exception(
            'Chat server error ${response.statusCode}',
          );
        }
      } on RateLimitException {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('RAG chat attempt $attempt timed out');
        if (attempt >= _maxRetries) break;
      } catch (e) {
        if (e is Exception) lastError = e;
        debugPrint('RAG chat error (attempt $attempt): $e');
        if (attempt >= _maxRetries) break;
      }
    }

    throw lastError ?? Exception('Failed to send chat message');
  }
}

/// Exception thrown when the client-side or server-side rate limit is hit.
class RateLimitException implements Exception {
  RateLimitException(this.message);
  final String message;

  @override
  String toString() => message;
}

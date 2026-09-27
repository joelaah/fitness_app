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
/// Handles authentication, payload serialization, error states, and local caching.
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

  /// Resolve the API base URL.
  ///
  /// For release builds: supply via --dart-define=RAG_API_URL=https://your-api.onrender.com
  /// For debug builds: automatically uses localhost (Android emulator-aware).
  static String _defaultBaseUrl() {
    // Optional override via --dart-define (e.g. --dart-define=RAG_API_URL=http://127.0.0.1:8000)
    const definedUrl = String.fromEnvironment('RAG_API_URL');
    if (definedUrl.isNotEmpty) return definedUrl;

    // Default live public cloud API URL
    return 'https://fitness-rag-api.onrender.com';
  }

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

  /// Fetch recommendations from the FastAPI backend.
  /// If [forceRefresh] is true, bypasses server cache and regenerates fresh guidance.
  ///
  /// Automatically retries up to [_maxRetries] times on timeout / server errors
  /// to handle Render.com cold-start latency transparently.
  Future<AiRecommendation> getRecommendations({
    bool forceRefresh = false,
    List<WorkoutSession>? sessions,
  }) async {
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
                  'completed_weight': st.completedWeight ?? st.targetWeight,
                  'is_completed': true,
                };
              }).toList(),
            };
          }).toList(),
        };
      }).toList();
    }

    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // Exponential backoff: 2s, 4s between retries
          final delay = Duration(seconds: 2 * attempt);
          debugPrint('RAG recommend retry $attempt after ${delay.inSeconds}s');
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
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final recommendation = AiRecommendation.fromJson(data);

          // Cache recommendation locally
          if (_prefs != null) {
            await _prefs.setString(_cacheKey, response.body);
          }

          return recommendation;
        } else if (response.statusCode >= 500 && attempt < _maxRetries) {
          // Server error (likely still waking up), retry
          lastError = Exception(
            'Server returned code ${response.statusCode}: ${response.body}',
          );
          continue;
        } else {
          throw Exception(
            'Server returned code ${response.statusCode}: ${response.body}',
          );
        }
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('RAG recommend attempt $attempt timed out');
        if (attempt >= _maxRetries) break;
        // continue to retry
      } catch (e) {
        if (e is Exception) lastError = e;
        debugPrint('RAG API Error (attempt $attempt): $e');
        if (attempt >= _maxRetries) break;
        // continue to retry
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

  /// Send a question to the conversational RAG chat endpoint.
  ///
  /// Automatically retries up to [_maxRetries] times on timeout / server errors
  /// to handle Render.com cold-start latency transparently.
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    final url = Uri.parse('$_baseUrl/chat');
    final token = _getAuthToken();

    Exception? lastError;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = Duration(seconds: 2 * attempt);
          debugPrint('RAG chat retry $attempt after ${delay.inSeconds}s');
          await Future<void>.delayed(delay);
        }

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'message': message}),
            )
            .timeout(const Duration(seconds: 90));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else if (response.statusCode >= 500 && attempt < _maxRetries) {
          lastError = Exception(
            'Chat server error ${response.statusCode}: ${response.body}',
          );
          continue;
        } else {
          throw Exception(
            'Chat server error ${response.statusCode}: ${response.body}',
          );
        }
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

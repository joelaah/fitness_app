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
class RagRecommendationService {
  RagRecommendationService({
    String? baseUrl,
    SharedPreferences? prefs,
  })  : _baseUrl = baseUrl ?? _defaultBaseUrl(),
        _prefs = prefs;

  final String _baseUrl;
  final SharedPreferences? _prefs;

  static const _cacheKey = 'cached_ai_recommendation';

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

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final recommendation = AiRecommendation.fromJson(data);

        // Cache recommendation locally
        if (_prefs != null) {
          await _prefs.setString(_cacheKey, response.body);
        }

        return recommendation;
      } else {
        throw Exception(
          'Server returned code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('RAG API Error: $e');
      // If we have a local cache, return it with cached = true
      final cached = getCachedRecommendation();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Send a question to the conversational RAG chat endpoint
  Future<Map<String, dynamic>> sendChatMessage(String message) async {
    final url = Uri.parse('$_baseUrl/chat');
    final token = _getAuthToken();

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Chat server error ${response.statusCode}: ${response.body}',
      );
    }
  }
}

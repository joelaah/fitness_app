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
    http.Client? client,
    bool skipWarmUp = false,
  })  : _baseUrl = baseUrl ?? _defaultBaseUrl(),
        _prefs = prefs,
        _client = client ?? http.Client() {
    // Fire-and-forget warm-up ping so the server starts waking immediately
    if (!skipWarmUp) {
      warmUp();
    }
  }

  final String _baseUrl;
  final SharedPreferences? _prefs;
  final http.Client _client;

  static const _cacheKey = 'cached_ai_recommendation';

  /// Maximum number of automatic retries for cold-start failures
  static const _maxRetries = 1;

  /// Request timeout threshold. Render.com free-tier backends sleep after inactivity;
  /// if requests time out (>10s) or fail during warm-up, we gracefully fallback
  /// to local routine recommendations to prevent the client from freezing.
  static const _requestTimeout = Duration(seconds: 10);

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
      await _client
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

        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            )
            .timeout(_requestTimeout);

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
            'Server returned ${response.statusCode} (server warming up)',
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
        debugPrint('RAG recommend attempt $attempt timed out (>10s threshold reached)');
        // Render free-tier cold start detected. Break early rather than blocking client.
        break;
      } catch (e) {
        if (e is Exception) lastError = e;
        debugPrint('RAG API Error (attempt $attempt): $e');
        if (attempt >= _maxRetries) break;
      }
    }

    // Free-tier cold start or timeout (>10s) encountered:
    // Fire-and-forget background ping to wake Render server up
    warmUp();

    debugPrint('RAG API: Cold start or timeout (>10s) detected ($lastError). Falling back to local routine recommendations.');

    // Gracefully fallback to locally synthesized routine recommendations with warming-up notice
    return buildLocalFallbackRecommendation(sessions);
  }

  /// Synthesizes an evidence-based recommendation locally when the cloud
  /// backend is cold-starting or times out (>10s).
  static AiRecommendation buildLocalFallbackRecommendation(
    List<WorkoutSession>? sessions,
  ) {
    final list = sessions ?? const [];
    double totalVol = 0.0;
    int totalSets = 0;
    int totalReps = 0;
    final Map<String, double> volumeByMuscle = {
      'Chest': 0.0,
      'Back': 0.0,
      'Legs': 0.0,
      'Shoulders': 0.0,
      'Arms': 0.0,
      'Core': 0.0,
    };

    for (final s in list) {
      final routineLower = (s.routineName ?? '').toLowerCase();
      for (final ex in s.exercises) {
        if (ex.isSkipped) continue;
        for (final st in ex.sets) {
          if (!st.isCompleted) continue;
          final weight = st.completedWeight ?? st.targetWeight;
          final reps = st.completedReps ?? st.targetReps;
          final vol = weight * reps;
          totalVol += vol;
          totalSets += 1;
          totalReps += reps;

          if (routineLower.contains('upper') || routineLower.contains('push')) {
            volumeByMuscle['Chest'] = (volumeByMuscle['Chest'] ?? 0) + (vol * 0.5);
            volumeByMuscle['Shoulders'] = (volumeByMuscle['Shoulders'] ?? 0) + (vol * 0.3);
            volumeByMuscle['Arms'] = (volumeByMuscle['Arms'] ?? 0) + (vol * 0.2);
          } else if (routineLower.contains('pull') || routineLower.contains('back')) {
            volumeByMuscle['Back'] = (volumeByMuscle['Back'] ?? 0) + (vol * 0.7);
            volumeByMuscle['Arms'] = (volumeByMuscle['Arms'] ?? 0) + (vol * 0.3);
          } else if (routineLower.contains('lower') || routineLower.contains('leg')) {
            volumeByMuscle['Legs'] = (volumeByMuscle['Legs'] ?? 0) + (vol * 0.8);
            volumeByMuscle['Core'] = (volumeByMuscle['Core'] ?? 0) + (vol * 0.2);
          } else {
            volumeByMuscle['Chest'] = (volumeByMuscle['Chest'] ?? 0) + (vol * 0.25);
            volumeByMuscle['Back'] = (volumeByMuscle['Back'] ?? 0) + (vol * 0.25);
            volumeByMuscle['Legs'] = (volumeByMuscle['Legs'] ?? 0) + (vol * 0.35);
            volumeByMuscle['Arms'] = (volumeByMuscle['Arms'] ?? 0) + (vol * 0.15);
          }
        }
      }
    }

    final activeVolumes = <String, double>{};
    volumeByMuscle.forEach((k, v) {
      if (v > 0) activeVolumes[k] = double.parse(v.toStringAsFixed(1));
    });

    final sortedMuscles = activeVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostTrained = sortedMuscles.take(3).map((e) => e.key).toList();
    if (mostTrained.isEmpty) mostTrained.add('Full Body');

    final recentlyUntrained = volumeByMuscle.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList();

    String nextTitle = 'Upper Body Power';
    String nextReason =
        'Optimizes upper-body push & pull volume while allowing lower body recovery.';
    List<NextExerciseItem> nextExercises = const [
      NextExerciseItem(
        name: 'Incline Dumbbell Press',
        reason: 'Target clavicular head of pectoralis major for upper chest fullness.',
      ),
      NextExerciseItem(
        name: 'Barbell Bent Over Row',
        reason: 'Compound horizontal pulling for lat and rhomboid thickness.',
      ),
      NextExerciseItem(
        name: 'Dumbbell Lateral Raise',
        reason: 'Medial deltoid hypertrophy and shoulder width.',
      ),
      NextExerciseItem(
        name: 'Cable Tricep Pushdown',
        reason: 'Lateral tricep head lockout strength and elbow stability.',
      ),
    ];

    if (list.isNotEmpty) {
      final lastRoutine = (list.first.routineName ?? '').toLowerCase();
      if (lastRoutine.contains('upper') || lastRoutine.contains('push')) {
        nextTitle = 'Lower Body Strength & Hypertrophy';
        nextReason =
            'Allows upper body recovery while targeting quadriceps and posterior chain.';
        nextExercises = const [
          NextExerciseItem(
            name: 'Barbell Full Squat',
            reason: 'Primary compound quad and glute strength builder.',
          ),
          NextExerciseItem(
            name: 'Barbell Romanian Deadlift',
            reason: 'Hamstring eccentric loading and posterior chain strength.',
          ),
          NextExerciseItem(
            name: 'Lever Leg Extension',
            reason: 'Isolated rectus femoris peak contraction.',
          ),
          NextExerciseItem(
            name: 'Standing Calf Raise',
            reason: 'Gastrocnemius volume and ankle stability.',
          ),
        ];
      }
    }

    return AiRecommendation(
      summary: RecommendationSummary(
        sessionsAnalyzed: list.length,
        totalVolume: double.parse(totalVol.toStringAsFixed(1)),
        totalSets: totalSets,
        totalReps: totalReps,
        volumeByMuscleGroup: activeVolumes,
        mostTrainedMuscleGroups: mostTrained,
        recentlyUntrainedMuscleGroups: recentlyUntrained,
        trainingFrequencyPerWeek: list.isNotEmpty ? 3.5 : null,
        averageDaysBetweenWorkouts: list.isNotEmpty ? 2.0 : null,
      ),
      recommendations: const [
        SingleRecommendation(
          title: 'Cloud AI Server Warming Up',
          category: 'server_notice',
          description:
              'The free-tier AI backend is waking up (~30-60s cold start). Showing locally synthesized workout guidance based on your history.',
          priority: 'high',
        ),
        SingleRecommendation(
          title: 'Progressive Overload Focus',
          category: 'training',
          description:
              'Maintain consistent progressive overload. Aim to add 1 rep or 1-2.5 kg compared to your last session on primary lifts.',
          priority: 'normal',
        ),
      ],
      recovery: const [
        RecoveryItem(
          title: 'Sleep & Central Nervous System Recovery',
          description:
              'Aim for 7-9 hours of restful sleep to optimize growth hormone release and glycogen replenishment.',
        ),
        RecoveryItem(
          title: 'Hydration & Electrolytes',
          description:
              'Drink 500ml of water with electrolytes 30 minutes before training to preserve muscular endurance.',
        ),
      ],
      nextWorkout: NextWorkout(
        title: nextTitle,
        reason: nextReason,
        exercises: nextExercises,
      ),
      generatedAt: DateTime.now(),
      sessionsAnalyzed: list.length,
      cached: false,
      pipelineSource: 'local_fallback',
    );
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

        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'message': sanitized}),
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else if (response.statusCode == 429) {
          throw RateLimitException(
            'The AI server is busy. Please try again in a minute.',
          );
        } else if (response.statusCode >= 500 &&
            attempt < _maxRetries) {
          lastError = Exception(
            'Chat server error ${response.statusCode} (server warming up)',
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
        debugPrint('RAG chat attempt $attempt timed out (>10s threshold reached)');
        break;
      } catch (e) {
        if (e is Exception) lastError = e;
        debugPrint('RAG chat error (attempt $attempt): $e');
        if (attempt >= _maxRetries) break;
      }
    }

    // Fire background warmUp ping
    warmUp();

    debugPrint(
      'RAG Chat: Cold start or timeout (>10s) detected ($lastError). Returning fallback guidance.',
    );

    // Graceful fallback response when Render backend is waking up
    return {
      'reply':
          'The AI Coach server is currently spinning up from cold sleep (Render free-tier). In the meantime, focus on progressive overload, 7-9 hours of sleep, and stay consistent with your scheduled workouts! Please try asking again in ~30 seconds once the server is awake.',
      'sources': ['Local Coach Guide'],
      'pipeline_source': 'local_fallback',
    };
  }
}

/// Exception thrown when the client-side or server-side rate limit is hit.
class RateLimitException implements Exception {
  const RateLimitException(this.message);
  final String message;

  @override
  String toString() => message;
}

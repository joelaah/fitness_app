import 'dart:async';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/services/rag_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RagRecommendationService Local Fallback Tests', () {
    test('buildLocalFallbackRecommendation handles empty sessions gracefully', () {
      final rec = RagRecommendationService.buildLocalFallbackRecommendation(null);

      expect(rec.pipelineSource, 'local_fallback');
      expect(rec.sessionsAnalyzed, 0);
      expect(rec.summary.totalVolume, 0.0);
      expect(rec.summary.totalSets, 0);
      expect(rec.summary.totalReps, 0);
      expect(rec.recommendations, isNotEmpty);
      expect(rec.recommendations.first.title, contains('Server Warming Up'));
      expect(rec.nextWorkout.title, isNotEmpty);
      expect(rec.nextWorkout.exercises, isNotEmpty);
    });

    test('buildLocalFallbackRecommendation computes stats and sets lower body next workout after upper session', () {
      final session = WorkoutSession(
        id: 'test-session-1',
        routineId: 'routine-1',
        dayId: 'day-1',
        routineName: 'Upper Body A',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 3600,
        totalVolume: 5000,
        totalReps: 50,
        exercises: [
          SessionExercise(
            id: 'ex-1',
            exerciseId: '0025',
            sets: [
              ExerciseSet(
                id: 'set-1',
                targetReps: 10,
                targetWeight: 60,
                completedReps: 10,
                completedWeight: 60,
                isCompleted: true,
              ),
              ExerciseSet(
                id: 'set-2',
                targetReps: 10,
                targetWeight: 60,
                completedReps: 10,
                completedWeight: 60,
                isCompleted: true,
              ),
            ],
          ),
        ],
      );

      final rec = RagRecommendationService.buildLocalFallbackRecommendation([session]);

      expect(rec.pipelineSource, 'local_fallback');
      expect(rec.sessionsAnalyzed, 1);
      expect(rec.summary.totalVolume, 1200.0);
      expect(rec.summary.totalSets, 2);
      expect(rec.summary.totalReps, 20);
      expect(rec.summary.volumeByMuscleGroup, contains('Chest'));
      expect(rec.nextWorkout.title, contains('Lower Body'));
      expect(rec.nextWorkout.exercises, isNotEmpty);
    });

    test('getRecommendations gracefully falls back to local routine on TimeoutException without throwing', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Render free-tier backend is sleeping (>10s threshold reached)');
      });

      final service = RagRecommendationService(
        baseUrl: 'https://test-fitness-api.onrender.com',
        client: mockClient,
      );

      final rec = await service.getRecommendations(sessions: []);

      expect(rec.pipelineSource, 'local_fallback');
      expect(rec.recommendations, isNotEmpty);
      expect(rec.recommendations.first.title, contains('Server Warming Up'));
      expect(rec.nextWorkout.title, isNotEmpty);
    });

    test('getRecommendations gracefully falls back to local routine on 502/503 Render boot response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad Gateway (Server Spinning Up)', 502);
      });

      final service = RagRecommendationService(
        baseUrl: 'https://test-fitness-api.onrender.com',
        client: mockClient,
      );

      final rec = await service.getRecommendations(sessions: []);

      expect(rec.pipelineSource, 'local_fallback');
      expect(rec.recommendations.first.title, contains('Server Warming Up'));
      expect(rec.nextWorkout.exercises, isNotEmpty);
    });

    test('sendChatMessage gracefully returns fallback message on timeout without throwing', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Render backend timeout');
      });

      final service = RagRecommendationService(
        baseUrl: 'https://test-fitness-api.onrender.com',
        client: mockClient,
      );

      final res = await service.sendChatMessage('How should I structure my sets?');

      expect(res['pipeline_source'], 'local_fallback');
      expect(res['reply'], contains('spinning up'));
      expect(res['sources'], contains('Local Coach Guide'));
    });

    test('sendChatMessage gracefully returns fallback message on 503 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final service = RagRecommendationService(
        baseUrl: 'https://test-fitness-api.onrender.com',
        client: mockClient,
      );

      final res = await service.sendChatMessage('What is progressive overload?');

      expect(res['pipeline_source'], 'local_fallback');
      expect(res['reply'], contains('spinning up'));
    });
  });
}

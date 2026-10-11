class RecommendationSummary {
  const RecommendationSummary({
    required this.sessionsAnalyzed,
    required this.totalVolume,
    required this.totalSets,
    required this.totalReps,
    required this.volumeByMuscleGroup,
    required this.mostTrainedMuscleGroups,
    required this.recentlyUntrainedMuscleGroups,
    this.trainingFrequencyPerWeek,
    this.averageDaysBetweenWorkouts,
  });

  final int sessionsAnalyzed;
  final double totalVolume;
  final int totalSets;
  final int totalReps;
  final Map<String, double> volumeByMuscleGroup;
  final List<String> mostTrainedMuscleGroups;
  final List<String> recentlyUntrainedMuscleGroups;
  final double? trainingFrequencyPerWeek;
  final double? averageDaysBetweenWorkouts;

  factory RecommendationSummary.fromJson(Map<String, dynamic> json) {
    final rawVolumeMap = json['volume_by_muscle_group'] as Map<String, dynamic>?;
    final volumeMap = <String, double>{};
    if (rawVolumeMap != null) {
      rawVolumeMap.forEach((k, v) {
        if (v is num) volumeMap[k] = v.toDouble();
      });
    }

    return RecommendationSummary(
      sessionsAnalyzed: (json['sessions_analyzed'] as num?)?.toInt() ?? 0,
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
      totalSets: (json['total_sets'] as num?)?.toInt() ?? 0,
      totalReps: (json['total_reps'] as num?)?.toInt() ?? 0,
      volumeByMuscleGroup: volumeMap,
      mostTrainedMuscleGroups: (json['most_trained_muscle_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      recentlyUntrainedMuscleGroups:
          (json['recently_untrained_muscle_groups'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      trainingFrequencyPerWeek:
          (json['training_frequency_per_week'] as num?)?.toDouble(),
      averageDaysBetweenWorkouts:
          (json['average_days_between_workouts'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sessions_analyzed': sessionsAnalyzed,
        'total_volume': totalVolume,
        'total_sets': totalSets,
        'total_reps': totalReps,
        'volume_by_muscle_group': volumeByMuscleGroup,
        'most_trained_muscle_groups': mostTrainedMuscleGroups,
        'recently_untrained_muscle_groups': recentlyUntrainedMuscleGroups,
        'training_frequency_per_week': trainingFrequencyPerWeek,
        'average_days_between_workouts': averageDaysBetweenWorkouts,
      };
}

class SingleRecommendation {
  const SingleRecommendation({
    required this.title,
    required this.category,
    required this.description,
    this.priority = 'normal',
  });

  final String title;
  final String category;
  final String description;
  final String priority;

  factory SingleRecommendation.fromJson(Map<String, dynamic> json) {
    return SingleRecommendation(
      title: json['title'] as String? ?? 'Training Recommendation',
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'description': description,
        'priority': priority,
      };
}

class RecoveryItem {
  const RecoveryItem({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  factory RecoveryItem.fromJson(Map<String, dynamic> json) {
    return RecoveryItem(
      title: json['title'] as String? ?? 'Recovery Guidance',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
      };
}

class NextExerciseItem {
  const NextExerciseItem({
    required this.name,
    required this.reason,
  });

  final String name;
  final String reason;

  factory NextExerciseItem.fromJson(Map<String, dynamic> json) {
    return NextExerciseItem(
      name: json['name'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'reason': reason,
      };
}

class NextWorkout {
  const NextWorkout({
    required this.title,
    required this.reason,
    required this.exercises,
  });

  final String title;
  final String reason;
  final List<NextExerciseItem> exercises;

  factory NextWorkout.fromJson(Map<String, dynamic> json) {
    return NextWorkout(
      title: json['title'] as String? ?? 'Next Suggested Routine',
      reason: json['reason'] as String? ?? '',
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => NextExerciseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'reason': reason,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

class AiRecommendation {
  const AiRecommendation({
    required this.summary,
    required this.recommendations,
    required this.recovery,
    required this.nextWorkout,
    required this.generatedAt,
    required this.sessionsAnalyzed,
    this.cached = false,
    this.pipelineSource = 'rag',
  });

  final RecommendationSummary summary;
  final List<SingleRecommendation> recommendations;
  final List<RecoveryItem> recovery;
  final NextWorkout nextWorkout;
  final DateTime generatedAt;
  final int sessionsAnalyzed;
  final bool cached;
  final String pipelineSource;

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    return AiRecommendation(
      summary: json['summary'] != null
          ? RecommendationSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const RecommendationSummary(
              sessionsAnalyzed: 0,
              totalVolume: 0,
              totalSets: 0,
              totalReps: 0,
              volumeByMuscleGroup: {},
              mostTrainedMuscleGroups: [],
              recentlyUntrainedMuscleGroups: [],
            ),
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => SingleRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recovery: (json['recovery'] as List<dynamic>?)
              ?.map((e) => RecoveryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nextWorkout: json['next_workout'] != null
          ? NextWorkout.fromJson(json['next_workout'] as Map<String, dynamic>)
          : const NextWorkout(
              title: 'Balanced Workout',
              reason: 'Keep training consistently',
              exercises: [],
            ),
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sessionsAnalyzed: (json['sessions_analyzed'] as num?)?.toInt() ?? 0,
      cached: json['cached'] as bool? ?? false,
      pipelineSource: json['pipeline_source'] as String? ?? 'rag',
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'recommendations': recommendations.map((e) => e.toJson()).toList(),
        'recovery': recovery.map((e) => e.toJson()).toList(),
        'next_workout': nextWorkout.toJson(),
        'generated_at': generatedAt.toIso8601String(),
        'sessions_analyzed': sessionsAnalyzed,
        'cached': cached,
        'pipeline_source': pipelineSource,
      };
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:flutter/material.dart';

class WorkoutBalanceCard extends StatelessWidget {
  const WorkoutBalanceCard({
    required this.dayExercises,
    required this.exerciseMap,
    super.key,
  });

  final List<RoutineExercise> dayExercises;
  final Map<String, Exercise> exerciseMap;

  @override
  Widget build(BuildContext context) {
    if (dayExercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final exercises = dayExercises
        .map((re) => exerciseMap[re.exerciseId])
        .whereType<Exercise>()
        .toList();

    if (exercises.isEmpty) return const SizedBox.shrink();

    // Tally muscle groups and sub-targets
    final groupCounts = <String, int>{};
    final subTargetCounts = <String, int>{};

    for (final ex in exercises) {
      final g = ex.primaryMuscleGroup;
      final st = ex.detailedTarget;
      groupCounts[g] = (groupCounts[g] ?? 0) + 1;
      subTargetCounts[st] = (subTargetCounts[st] ?? 0) + 1;
    }

    final adviceList = _generateSmartAdvice(groupCounts, subTargetCounts);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: ElevatedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_graph,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Smart Muscle Balance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: adviceList.any((a) => a.isWarning)
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    adviceList.any((a) => a.isWarning)
                        ? (adviceList.any(
                                (a) =>
                                    a.isWarning &&
                                    (a.message.contains('tension') ||
                                        a.message.contains('volume')),
                              )
                              ? 'High tension'
                              : 'Tips available')
                        : 'Balanced',
                    style: TextStyle(
                      color: adviceList.any((a) => a.isWarning)
                          ? Colors.amber
                          : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Distribution tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: subTargetCounts.entries.map((entry) {
                final subTarget = entry.key;
                final count = entry.value;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subTarget,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            if (adviceList.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),
              ...adviceList.map((advice) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        advice.isWarning
                            ? Icons.info_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: advice.isWarning
                            ? Colors.amber.shade300
                            : Colors.greenAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          advice.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: advice.isWarning
                                ? Colors.amber.shade100
                                : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  List<_BalanceAdvice> _generateSmartAdvice(
    Map<String, int> groupCounts,
    Map<String, int> subCounts,
  ) {
    final advice = <_BalanceAdvice>[];

    final chestCount = groupCounts['Chest'] ?? 0;
    if (chestCount > 0) {
      final upper = subCounts['Upper Chest'] ?? 0;
      final mid = subCounts['Mid Chest'] ?? 0;
      final lower = subCounts['Lower Chest'] ?? 0;

      if (mid >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'Heavy Mid Chest volume ($mid exercises). High shoulder and '
                'pectoral strain — consider varying the angle or volume.',
            isWarning: true,
          ),
        );
      } else if (mid >= 2 && upper == 0) {
        advice.add(
          _BalanceAdvice(
            message:
                'You have $mid Mid Chest exercises but no Upper Chest. '
                'Consider swapping one for an Incline Press for balance.',
            isWarning: true,
          ),
        );
      } else if (upper > 0 && (mid > 0 || lower > 0)) {
        advice.add(
          _BalanceAdvice(
            message:
                'Great chest balance! Upper and ${mid > 0 ? 'Mid' : 'Lower'} '
                'angles are both engaged.',
            isWarning: false,
          ),
        );
      }
    }

    final shoulderCount = groupCounts['Shoulders'] ?? 0;
    if (shoulderCount > 0) {
      final front = subCounts['Front Delts'] ?? 0;
      final side = subCounts['Side Delts'] ?? 0;
      final rear = subCounts['Rear Delts'] ?? 0;

      if (front >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'Heavy Front Delt volume ($front exercises). Watch anterior '
                'shoulder wear — add Side or Rear Delts.',
            isWarning: true,
          ),
        );
      } else if (front >= 2 && side == 0 && rear == 0) {
        advice.add(
          _BalanceAdvice(
            message:
                'Shoulder presses hit Front Delts. Add Lateral Raises '
                'or Face Pulls for rounded 3D shoulders.',
            isWarning: true,
          ),
        );
      }
    }

    final legCount = groupCounts['Legs'] ?? 0;
    if (legCount > 0) {
      final quads = subCounts['Quads'] ?? 0;
      final hams = subCounts['Hamstrings'] ?? 0;
      final glutes = subCounts['Glutes'] ?? 0;

      if (quads >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'High Quad volume ($quads exercises). High patellar tension '
                '— balance with hamstring or hip hinge movements.',
            isWarning: true,
          ),
        );
      } else if (quads >= 2 && hams == 0 && glutes == 0) {
        advice.add(
          _BalanceAdvice(
            message:
                'Multiple Quad exercises detected. Add Hamstrings '
                '(e.g. RDL or Leg Curl) to maintain joint balance.',
            isWarning: true,
          ),
        );
      }
    }

    final backCount = groupCounts['Back'] ?? 0;
    if (backCount > 0) {
      final lats = subCounts['Lats'] ?? 0;
      final upperBack = subCounts['Upper Back'] ?? 0;
      final lowerBack = subCounts['Lower Back'] ?? 0;

      if (upperBack >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'High Upper Back volume ($upperBack exercises). Too much '
                'cumulative tension on traps & rhomboids — consider swapping '
                'some for Lats or Lower Back.',
            isWarning: true,
          ),
        );
      } else if (upperBack >= 2 && lats == 0) {
        advice.add(
          _BalanceAdvice(
            message:
                'All horizontal rowing ($upperBack exercises) with no vertical '
                'pulling. Add a Pull-up or Lat Pulldown for Lats.',
            isWarning: true,
          ),
        );
      }

      if (lats >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'Heavy Lat volume ($lats exercises). High pulling fatigue '
                '— ensure adequate rest and balance with rows.',
            isWarning: true,
          ),
        );
      } else if (lats >= 2 && upperBack == 0) {
        advice.add(
          _BalanceAdvice(
            message:
                'All vertical pulling ($lats exercises) with no horizontal '
                'rowing. Add a row variation for Upper Back and posture.',
            isWarning: true,
          ),
        );
      }

      if (lowerBack >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'Multiple Lower Back exercises ($lowerBack). Watch spinal '
                'erector fatigue and heavy axial loading.',
            isWarning: true,
          ),
        );
      }

      if (lats > 0 && upperBack > 0 && upperBack < 3 && lats < 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'Balanced back day! Vertical (Lats) and horizontal '
                'rowing (Upper Back) covered.',
            isWarning: false,
          ),
        );
      }
    }

    final armCount = groupCounts['Arms'] ?? 0;
    if (armCount > 0) {
      final biceps = subCounts['Biceps'] ?? 0;
      final triceps = subCounts['Triceps'] ?? 0;

      if (biceps >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'High direct Bicep volume ($biceps exercises). Watch distal '
                'biceps tendon fatigue.',
            isWarning: true,
          ),
        );
      }
      if (triceps >= 3) {
        advice.add(
          _BalanceAdvice(
            message:
                'High direct Tricep volume ($triceps exercises). Watch elbow '
                'tendon strain from heavy extensions.',
            isWarning: true,
          ),
        );
      }
    }

    return advice;
  }
}

class _BalanceAdvice {
  _BalanceAdvice({required this.message, required this.isWarning});

  final String message;
  final bool isWarning;
}

import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkoutActiveScreen extends StatefulWidget {
  const WorkoutActiveScreen({super.key});

  @override
  State<WorkoutActiveScreen> createState() => _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends State<WorkoutActiveScreen> {
  // Cache the full exercises so we don't reload on every rebuild
  late Future<Map<String, Exercise>> _exerciseMapFuture;

  @override
  void initState() {
    super.initState();
    _exerciseMapFuture = _loadExercises();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Format a previous set as a compact string like "60 × 10" or "10 reps"
  String _formatPrev(ExerciseSet? prev, bool isBodyweight) {
    if (prev == null) return '—';
    final r = prev.completedReps ?? prev.targetReps;
    if (isBodyweight) {
      return '$r reps';
    }
    final w = prev.completedWeight ?? prev.targetWeight;
    final weightStr = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
    return '$weightStr × $r';
  }

  void _confirmFinish() {
    final provider = context.read<WorkoutProvider>();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text(
          'This will save your workout and update your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Finish',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await provider.finishWorkout();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _confirmCancel() {
    final provider = context.read<WorkoutProvider>();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text(
          'Progress will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel Workout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        provider.cancelWorkout();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final session = provider.activeSession;

    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('No active workout')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              provider.isPaused ? 'Workout Paused' : 'Active Workout',
              style: TextStyle(
                fontSize: 13,
                color: provider.isPaused
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            Text(
              _formatDuration(provider.workoutDuration),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
        actions: [
          IconButton(
            icon: Icon(
              provider.isPaused ? Icons.play_arrow : Icons.pause,
              color: AppColors.primary,
            ),
            onPressed: () {
              if (provider.isPaused) {
                provider.resumeWorkout();
              } else {
                provider.pauseWorkout();
              }
            },
          ),
          TextButton(
            onPressed: _confirmFinish,
            child: const Text(
              'Finish',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Exercise>>(
        future: _exerciseMapFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exerciseMap = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              // Extra space so the rest timer banner doesn't cover last card
              bottom: provider.isResting ? 80 : AppSpacing.md,
            ),
            itemCount: session.exercises.length,
            itemBuilder: (context, index) {
              final sessionEx = session.exercises[index];
              final exercise = exerciseMap[sessionEx.exerciseId];
              final exName = exercise?.name ?? 'Unknown Exercise';
              final isBodyweight =
                  exercise?.equipment.toLowerCase() == 'body weight';
              final prevSets = provider.previousSets[sessionEx.exerciseId];

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ElevatedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise header row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    decoration: sessionEx.isSkipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: sessionEx.isSkipped
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onSelected: (value) {
                              if (value == 'skip') {
                                provider.skipExercise(sessionEx.id);
                              } else if (value == 'unskip') {
                                provider.unskipExercise(sessionEx.id);
                              }
                            },
                            itemBuilder: (context) => [
                              if (!sessionEx.isSkipped)
                                const PopupMenuItem(
                                  value: 'skip',
                                  child: Text('Skip Exercise'),
                                ),
                              if (sessionEx.isSkipped)
                                const PopupMenuItem(
                                  value: 'unskip',
                                  child: Text('Unskip Exercise'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Column headers
                      if (!sessionEx.isSkipped) ...[
                        Row(
                          children: [
                            const SizedBox(
                              width: 32,
                              child: Text(
                                'Set',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Previous',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isBodyweight ? '' : 'Weight',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Reps',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 36,
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.border, height: 16),

                        // Set rows
                        ...sessionEx.sets.asMap().entries.map((entry) {
                          final setIndex = entry.key;
                          final set = entry.value;
                          final prev =
                              (prevSets != null && setIndex < prevSets.length)
                              ? prevSets[setIndex]
                              : null;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: set.isCompleted
                                  ? AppColors.primary.withAlpha(30)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                // Set number
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${setIndex + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: set.isCompleted
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                // Previous
                                Expanded(
                                  child: Text(
                                    _formatPrev(prev, isBodyweight),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                // Weight input
                                Expanded(
                                  child: isBodyweight
                                      ? Container(
                                          height: 34,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'BODYWEIGHT',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        )
                                      : _buildInputBox(
                                          value:
                                              set.completedWeight?.toString() ??
                                              (set.targetWeight > 0
                                                  ? set.targetWeight.toString()
                                                  : ''),
                                          isCompleted: set.isCompleted,
                                          hint: '0',
                                          onChanged: (val) {
                                            final w = double.tryParse(val);
                                            if (w != null) {
                                              provider.updateSetValues(
                                                sessionEx.id,
                                                set.id,
                                                weight: w,
                                              );
                                            }
                                          },
                                        ),
                                ),
                                const SizedBox(width: 8),
                                // Reps input
                                Expanded(
                                  child: _buildInputBox(
                                    value:
                                        set.completedReps?.toString() ??
                                        set.targetReps.toString(),
                                    isCompleted: set.isCompleted,
                                    hint: '—',
                                    onChanged: (val) {
                                      final r = int.tryParse(val);
                                      if (r != null) {
                                        provider.updateSetValues(
                                          sessionEx.id,
                                          set.id,
                                          reps: r,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Complete checkmark
                                GestureDetector(
                                  onTap: () => provider.toggleSetComplete(
                                    sessionEx.id,
                                    set.id,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: set.isCompleted
                                          ? AppColors.primary
                                          : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    height: 34,
                                    width: 36,
                                    child: Icon(
                                      Icons.check,
                                      color: set.isCompleted
                                          ? AppColors.background
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Skipped',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Rest timer bottom banner
      bottomSheet: provider.isResting ? _buildRestBanner(provider) : null,
    );
  }

  Widget _buildRestBanner(WorkoutProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withAlpha(80),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Pulsing indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'REST — ${_formatDuration(Duration(seconds: provider.currentRestSeconds))}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => provider.adjustRestTime(-30),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text(
                '−30s',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () => provider.adjustRestTime(30),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text(
                '+30s',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () => provider.skipRest(),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required String value,
    required bool isCompleted,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: isCompleted ? Colors.transparent : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: isCompleted
          ? Text(
              value.isEmpty ? hint : value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          : TextFormField(
              initialValue: value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
              ),
              onChanged: onChanged,
            ),
    );
  }

  Future<Map<String, Exercise>> _loadExercises() async {
    final exercises = await ExerciseService.loadExercises();
    return {for (final e in exercises) e.id: e};
  }
}

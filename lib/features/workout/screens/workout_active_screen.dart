import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/glowing_progress_bar.dart';
import 'package:fitness_app/core/widgets/shimmer_skeleton.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/widgets/workout_summary_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  double _calculateProgress(WorkoutSession? session) {
    if (session == null) return 0.0;
    final totalSets = session.exercises
        .where((e) => !e.isSkipped)
        .expand((e) => e.sets)
        .length;
    if (totalSets == 0) return 0.0;
    final completedSets = session.exercises
        .where((e) => !e.isSkipped)
        .expand((e) => e.sets)
        .where((s) => s.isCompleted)
        .length;
    return completedSets / totalSets;
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
        final routineName = provider.activeSession?.routineName ?? 'Workout';
        final durationSec = provider.workoutDuration.inSeconds;
        final totalSets = provider.activeSession?.exercises
                .where((e) => !e.isSkipped)
                .expand((e) => e.sets)
                .where((s) => s.isCompleted)
                .length ??
            0;
        final totalReps = provider.activeSession?.exercises
                .where((e) => !e.isSkipped)
                .expand((e) => e.sets)
                .where((s) => s.isCompleted)
                .fold<int>(0, (sum, s) => sum + (s.completedReps ?? s.targetReps)) ??
            0;

        await provider.finishWorkout();
        if (mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => WorkoutSummaryDialog(
              routineName: routineName,
              durationSeconds: durationSec,
              totalVolumeKg: provider.lastOverload?.currentVolume ?? 0,
              totalReps: totalReps,
              totalSets: totalSets,
              overload: provider.lastOverload,
              intensity: provider.lastIntensity,
              calorieBurn: provider.lastCalorieBurn,
            ),
          );
          if (mounted) Navigator.pop(context);
        }
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (provider.isPaused
                        ? AppColors.warning
                        : AppColors.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (provider.isPaused
                          ? AppColors.warning
                          : AppColors.primary)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: provider.isPaused
                          ? AppColors.warning
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isPaused ? 'Workout Paused' : 'Active Workout',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: provider.isPaused
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDuration(provider.workoutDuration),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: GlowingProgressBar(
            progress: _calculateProgress(session),
            height: 3,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, Exercise>>(
        future: _exerciseMapFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ShimmerWorkoutActiveSkeleton();
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
                                    fontWeight: FontWeight.bold,
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
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Previous',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                isBodyweight ? '' : 'Weight',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
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
                                  fontWeight: FontWeight.w600,
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
                                  ? AppColors.primary.withAlpha(28)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: set.isCompleted
                                    ? AppColors.primary.withAlpha(50)
                                    : Colors.transparent,
                              ),
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
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
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
                                      fontWeight: FontWeight.w500,
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
                                // Complete checkmark with glowing tactile response
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    provider.toggleSetComplete(
                                      sessionEx.id,
                                      set.id,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: set.isCompleted
                                          ? AppColors.primary
                                          : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: set.isCompleted
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ]
                                          : null,
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
      // Rest timer bottom banner with ambient glow and athletic typography
      bottomSheet: provider.isResting ? _buildRestBanner(provider) : null,
    );
  }

  Widget _buildRestBanner(WorkoutProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Glowing rest badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'REST — ${_formatDuration(Duration(seconds: provider.currentRestSeconds))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.primary,
                      letterSpacing: 0.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
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
        border: Border.all(
          color: isCompleted
              ? AppColors.primary.withAlpha(70)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      alignment: Alignment.center,
      child: isCompleted
          ? Text(
              value.isEmpty ? hint : value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )
          : _AutoSelectInputBox(
              value: value,
              hint: hint,
              onChanged: onChanged,
            ),
    );
  }

  Future<Map<String, Exercise>> _loadExercises() async {
    final exercises = await ExerciseService.loadExercises();
    return {for (final e in exercises) e.id: e};
  }
}

class _AutoSelectInputBox extends StatefulWidget {
  const _AutoSelectInputBox({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_AutoSelectInputBox> createState() => _AutoSelectInputBoxState();
}

class _AutoSelectInputBoxState extends State<_AutoSelectInputBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _selectAll();
      // Ensure gesture recognizer tap positioning doesn't clear selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _selectAll();
        }
      });
    }
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void didUpdateWidget(covariant _AutoSelectInputBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != _controller.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      onChanged: widget.onChanged,
    );
  }
}

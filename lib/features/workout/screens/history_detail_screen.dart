import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({required this.session, super.key});

  final WorkoutSession session;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late Future<Map<String, Exercise>> _exerciseMapFuture;

  @override
  void initState() {
    super.initState();
    _exerciseMapFuture = _loadExercises();
  }

  Future<Map<String, Exercise>> _loadExercises() async {
    final exercises = await ExerciseService.loadExercises();
    return {for (final ex in exercises) ex.id: ex};
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.routineName ?? 'Workout Details'),
      ),
      body: FutureBuilder<Map<String, Exercise>>(
        future: _exerciseMapFuture,
        builder: (context, snapshot) {
          final exerciseMap = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Summary Header Card ──────────────────────────────
              _SummaryHeader(session: session),
              const SizedBox(height: 24),

              // ── Exercises section title ──────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Exercises',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ── Exercise cards ───────────────────────────────────
              ...List.generate(session.exercises.length, (i) {
                final ex = session.exercises[i];
                final info = exerciseMap[ex.exerciseId];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseCard(
                    exercise: ex,
                    index: i + 1,
                    name: info?.name ?? ex.exerciseId,
                    bodyPart: info?.bodyPart ?? '',
                    equipment: info?.equipment ?? '',
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ─── Summary Header ──────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedExercises = session.exercises
        .where((e) => !e.isSkipped)
        .length;
    final completedSets = session.exercises
        .expand((e) => e.sets)
        .where((s) => s.isCompleted)
        .length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(35),
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & time
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateFull(session.startTime),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (session.endTime != null)
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('h:mm a').format(session.startTime.toLocal())}'
                  ' – '
                  '${DateFormat('h:mm a').format(session.endTime!.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Stats grid: 2×2
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  value: _formatDuration(session.durationSeconds),
                  label: 'Duration',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.fitness_center,
                  value: _formatVolume(session.totalVolume),
                  label: 'Volume',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.replay_rounded,
                  value: '$completedSets',
                  label: 'Sets',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.list_alt_rounded,
                  value: '$completedExercises',
                  label: 'Exercises',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateFull(DateTime dt) {
    return DateFormat('EEEE, MMMM d, y').format(dt.toLocal());
  }

  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds == 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  String _formatVolume(double? volume) {
    if (volume == null || volume == 0) return '0 kg';
    if (volume >= 1000) {
      return '${NumberFormat('#,##0').format(volume.round())} kg';
    }
    return '${volume.round()} kg';
  }
}

// ─── Stat Tile (used in the 2×2 grid) ────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withAlpha(60),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Exercise Card ───────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.name,
    required this.bodyPart,
    required this.equipment,
  });
  final SessionExercise exercise;
  final int index;
  final String name;
  final String bodyPart;
  final String equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSkipped = exercise.isSkipped;
    final completedSets = exercise.sets.where((s) => s.isCompleted).toList();

    return ElevatedCard(
      child: Opacity(
        opacity: isSkipped ? 0.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header row
            Row(
              children: [
                // Index circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSkipped
                        ? AppColors.textSecondary.withAlpha(40)
                        : AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSkipped
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bodyPart.isNotEmpty || equipment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (bodyPart.isNotEmpty) bodyPart,
                              if (equipment.isNotEmpty) equipment,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSkipped)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      'Skipped',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),

            // Sets table (only if not skipped and has completed sets)
            if (!isSkipped && completedSets.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Table header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        'SET',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'WEIGHT',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'REPS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24), // status icon space
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Set rows
              ...List.generate(exercise.sets.length, (i) {
                final set = exercise.sets[i];
                return _SetRow(set: set, index: i + 1);
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Set Row ─────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.index});
  final ExerciseSet set;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = set.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withAlpha(40),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$index',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              completed && set.completedWeight != null
                  ? _formatWeight(set.completedWeight!)
                  : '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: completed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              completed && set.completedReps != null
                  ? '${set.completedReps}'
                  : '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: completed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 18,
              color: completed
                  ? AppColors.success
                  : AppColors.textSecondary.withAlpha(60),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double weight) {
    if (weight == 0) return 'BW';
    return weight % 1 == 0
        ? '${weight.toInt()} kg'
        : '${weight.toStringAsFixed(1)} kg';
  }
}

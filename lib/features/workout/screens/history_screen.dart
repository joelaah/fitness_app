import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/workout/models/workout_session.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/screens/history_detail_screen.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final hasSessions = provider.historyRepository.getAll().isNotEmpty;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'By Routine'),
                ],
              ),
            ),
            body: hasSessions
                ? TabBarView(
                    children: [
                      _AllHistoryView(),
                      _ByRoutineHistoryView(),
                    ],
                  )
                : const Center(
                    child: EmptyStateWidget(
                      icon: Icons.history_rounded,
                      title: 'No Workouts Yet',
                      description:
                          'Your completed workouts will show up here.\\nGo crush a session!',
                    ),
                  ),
          ),
        );
      },
    );
  }

}

/// A single workout history card.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exerciseCount = session.exercises.where((e) => !e.isSkipped).length;
    final completedSets = session.exercises
        .expand((e) => e.sets)
        .where((s) => s.isCompleted)
        .length;

    return ElevatedCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => HistoryDetailScreen(session: session),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: routine name + time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Green accent dot
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.routineName ?? 'Workout',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('h:mm a').format(session.startTime.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.timer_outlined,
                  label: _formatDuration(session.durationSeconds),
                ),
                _dividerDot(),
                _StatChip(
                  icon: Icons.fitness_center,
                  label: _formatVolume(session.totalVolume),
                ),
                _dividerDot(),
                _StatChip(
                  icon: Icons.replay_rounded,
                  label: '$completedSets sets',
                ),
                _dividerDot(),
                _StatChip(
                  icon: Icons.list_alt_rounded,
                  label:
                      '$exerciseCount '
                      '${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerDot() {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withAlpha(80),
        shape: BoxShape.circle,
      ),
    );
  }

  /// Format seconds into a human-readable string: "45 min", "1h 12m", etc.
  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds == 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '$minutes min';
  }

  /// Format volume: "2,450 kg", "0 kg"
  String _formatVolume(double? volume) {
    if (volume == null || volume == 0) return '0 kg';
    if (volume >= 1000) {
      return '${NumberFormat('#,##0').format(volume.round())} kg';
    }
    return '${volume.round()} kg';
  }
}

/// Small icon + label stat chip used inside the workout card.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary.withAlpha(200)),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
// All History View - grouped by day
class _AllHistoryView extends StatelessWidget {
  const _AllHistoryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);
    final grouped = provider.sessionsByDay;
    final entries = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final dateLabel = _formatDateLabel(entry.key);
        final sessions = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...sessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkoutCard(session: s),
            ))
          ],
        );
      },
    );
  }

  String _formatDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('EEE, MMM d').format(dt);
  }
}

// By Routine History View - grouped by routine
class _ByRoutineHistoryView extends StatelessWidget {
  const _ByRoutineHistoryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);
    final grouped = provider.sessionsByRoutine;
    final entries = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final routineName = entry.key;
        final sessions = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                routineName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...sessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkoutCard(session: s),
            ))
          ],
        );
      },
    );
  }
}

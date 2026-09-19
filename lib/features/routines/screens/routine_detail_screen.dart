import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/theme/routine_theme_resolver.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/screens/workout_day_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({required this.routine, super.key});
  final WorkoutRoutine routine;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late WorkoutRoutine _routine;
  late RoutineVisualStyle _visualStyle;

  @override
  void initState() {
    super.initState();
    _routine = widget.routine;
    _visualStyle = RoutineThemeResolver.resolve(_routine.name);
  }

  void _saveRoutine() {
    context.read<RoutineProvider>().saveRoutine(_routine);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _routine.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_visualStyle.imageAsset != null)
                    Image.asset(
                      _visualStyle.imageAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          AppColors.background.withValues(alpha: 0.75),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final provider = context.read<RoutineProvider>();
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Routine?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm ?? false) {
                    await provider.deleteRoutine(_routine.id);
                    navigator.pop();
                  }
                },
              ),
            ],
          ),
          if (_routine.days.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.calendar_month,
                  title: 'No Days Yet',
                  description:
                      'Add days to this routine to start building your workout plan.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final day = _routine.days[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ElevatedCard(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<dynamic>(
                              builder: (context) => WorkoutDayScreen(
                                routine: _routine,
                                dayIndex: index,
                              ),
                            ),
                          );
                          setState(() {});
                          _saveRoutine();
                        },
                        padding: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _visualStyle.coverGradient.first
                                .withAlpha(25),
                            foregroundColor: _visualStyle.coverGradient.first,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            day.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${day.exercises.length} Exercises',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Day?'),
                                      content: const Text(
                                        'Are you sure you want to delete this day?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm ?? false) {
                                    setState(() {
                                      _routine.days.removeAt(index);
                                    });
                                    _saveRoutine();
                                  }
                                },
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _routine.days.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _visualStyle.coverGradient.first,
        foregroundColor: Colors.white,
        onPressed: () {
          setState(() {
            _routine.days.add(
              WorkoutDay(
                id: const Uuid().v4(),
                name: 'Day ${_routine.days.length + 1}',
              ),
            );
          });
          _saveRoutine();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Day',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

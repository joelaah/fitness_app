import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/theme/app_spacing.dart';
import 'package:fitness_app/core/widgets/elevated_card.dart';
import 'package:fitness_app/core/widgets/empty_state_widget.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:fitness_app/features/exercises/screens/exercise_picker_screen.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/widgets/workout_balance_card.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/screens/workout_active_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class WorkoutDayScreen extends StatefulWidget {
  const WorkoutDayScreen({
    required this.routine,
    required this.dayIndex,
    super.key,
  });
  final WorkoutRoutine routine;
  final int dayIndex;

  @override
  State<WorkoutDayScreen> createState() => _WorkoutDayScreenState();
}

class _WorkoutDayScreenState extends State<WorkoutDayScreen> {
  late WorkoutDay _day;
  Map<String, Exercise> _exerciseMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _day = widget.routine.days[widget.dayIndex];
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await ExerciseService.loadExercises();
    _exerciseMap = {for (final e in exercises) e.id: e};
    setState(() {
      _isLoading = false;
    });
  }

  void _saveDay() {
    context.read<RoutineProvider>().saveRoutine(widget.routine);
    setState(() {});
  }

  void _showConfigurationModal(
    BuildContext context,
    RoutineExercise routineExercise,
    Exercise? exerciseData,
  ) {
    var sets = routineExercise.sets;
    var reps = routineExercise.reps;

    showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Configure ${exerciseData?.name ?? 'Exercise'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Sets',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.primary,
                              ),
                              onPressed: sets > 1
                                  ? () => setModalState(() => sets--)
                                  : null,
                            ),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$sets',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              onPressed: () => setModalState(() => sets++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Reps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.primary,
                              ),
                              onPressed: reps > 1
                                  ? () => setModalState(() => reps--)
                                  : null,
                            ),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$reps',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.primary,
                              ),
                              onPressed: () => setModalState(() => reps++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            routineExercise.sets = sets;
                            routineExercise.reps = reps;
                          });
                          _saveDay();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Save Configuration',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_day.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _day.exercises.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.fitness_center,
              title: 'Empty Day',
              description:
                  'Add some exercises to this day to build your routine.',
            )
          : Column(
              children: [
                if (_day.exercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          context.read<WorkoutProvider>().startWorkout(
                            widget.routine,
                            _day,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute<dynamic>(
                              builder: (_) => const WorkoutActiveScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(
                          'START WORKOUT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                WorkoutBalanceCard(
                  dayExercises: _day.exercises,
                  exerciseMap: _exerciseMap,
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: _day.exercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _day.exercises.removeAt(oldIndex);
                        _day.exercises.insert(newIndex, item);
                      });
                      _saveDay();
                    },
                    itemBuilder: (context, index) {
                      final routineExercise = _day.exercises[index];
                      final exerciseData =
                          _exerciseMap[routineExercise.exerciseId];

                      return Padding(
                        key: ValueKey(routineExercise.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ElevatedCard(
                          onTap: () => _showConfigurationModal(
                            context,
                            routineExercise,
                            exerciseData,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.drag_handle,
                              color: AppColors.textSecondary,
                            ),
                            title: Text(
                              exerciseData?.name ?? 'Unknown Exercise',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (exerciseData != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 3,
                                      bottom: 4,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: exerciseData.subTargetBadgeColor
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        exerciseData.detailedTarget
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color:
                                              exerciseData.subTargetBadgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${routineExercise.sets} Sets × ${routineExercise.reps} Reps',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                _day.exercises.removeAt(index);
                                _saveDay();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              final selectedIds = await Navigator.push(
                context,
                MaterialPageRoute<List<String>>(
                  builder: (_) => const ExercisePickerScreen(),
                ),
              );

              if (selectedIds != null && selectedIds.isNotEmpty) {
                for (final id in selectedIds) {
                  _day.exercises.add(
                    RoutineExercise(id: const Uuid().v4(), exerciseId: id),
                  );
                }
                _saveDay();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text(
              'ADD EXERCISE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

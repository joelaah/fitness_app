import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/core/widgets/category_chip.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:fitness_app/features/exercises/widgets/exercise_card.dart';
import 'package:flutter/material.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Exercise> exercises = [];
  List<Exercise> filteredExercises = [];
  Set<String> allEquipment = {};

  bool isLoading = true;
  String searchQuery = '';
  String selectedMuscleGroup = 'All';
  String? selectedSubTarget;
  String? selectedEquipment;

  @override
  void initState() {
    super.initState();
    loadExercises();
  }

  Future<void> loadExercises() async {
    final loadedExercises = await ExerciseService.loadExercises();

    final equipmentSet = <String>{};
    for (final exercise in loadedExercises) {
      if (exercise.equipment.isNotEmpty) {
        equipmentSet.add(exercise.equipment);
      }
    }

    setState(() {
      exercises = loadedExercises;
      filteredExercises = loadedExercises;
      allEquipment = equipmentSet;
      isLoading = false;
    });
  }

  void _filterExercises() {
    setState(() {
      filteredExercises = exercises.where((exercise) {
        final matchesQuery =
            searchQuery.isEmpty ||
            exercise.name.toLowerCase().contains(searchQuery) ||
            exercise.detailedTarget.toLowerCase().contains(searchQuery) ||
            exercise.primaryMuscleGroup.toLowerCase().contains(searchQuery) ||
            exercise.bodyPart.toLowerCase().contains(searchQuery) ||
            exercise.target.toLowerCase().contains(searchQuery);

        final matchesMuscleGroup =
            selectedMuscleGroup == 'All' ||
            exercise.primaryMuscleGroup == selectedMuscleGroup;

        final matchesSubTarget =
            selectedSubTarget == null ||
            selectedSubTarget!.startsWith('All') ||
            exercise.detailedTarget == selectedSubTarget;

        final matchesEquipment =
            selectedEquipment == null ||
            exercise.equipment.toLowerCase() ==
                selectedEquipment!.toLowerCase();

        return matchesQuery &&
            matchesMuscleGroup &&
            matchesSubTarget &&
            matchesEquipment;
      }).toList();
    });
  }

  void searchExercises(String query) {
    searchQuery = query.toLowerCase().trim();
    _filterExercises();
  }

  void setMuscleGroupFilter(String group) {
    setState(() {
      selectedMuscleGroup = group;
      selectedSubTarget = null;
    });
    _filterExercises();
  }

  void setSubTargetFilter(String? subTarget) {
    setState(() {
      selectedSubTarget = subTarget;
    });
    _filterExercises();
  }

  void setEquipmentFilter(String? equipment) {
    setState(() {
      selectedEquipment = equipment;
    });
    _filterExercises();
  }

  @override
  Widget build(BuildContext context) {
    final availableSubTargets = ExerciseTargetData.subTargetsFor(
      selectedMuscleGroup,
    );

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text(
                      'Exercise Library',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    centerTitle: true,
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.background,
                            AppColors.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: searchExercises,
                          decoration: InputDecoration(
                            hintText: 'Search exercise, muscle, target...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 16),

                        // Muscle Group Selector
                        const Text(
                          'Muscle Group',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ExerciseTargetData.muscleGroups.map((
                              group,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CategoryChip(
                                  label: group,
                                  isSelected: selectedMuscleGroup == group,
                                  onTap: () => setMuscleGroupFilter(group),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Sub-Target Pills (e.g. Upper Chest, Mid Chest, Lower Chest)
                        if (availableSubTargets.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: availableSubTargets.map((subTarget) {
                                final isSelected =
                                    selectedSubTarget == subTarget ||
                                    (selectedSubTarget == null &&
                                        subTarget.startsWith('All'));
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(subTarget),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setSubTargetFilter(
                                        subTarget.startsWith('All')
                                            ? null
                                            : subTarget,
                                      );
                                    },
                                    selectedColor: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    checkmarkColor: AppColors.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    backgroundColor: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        // Equipment Filter Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CategoryChip(
                                  label: 'All Equipment',
                                  isSelected: selectedEquipment == null,
                                  onTap: () => setEquipmentFilter(null),
                                ),
                              ),
                              ...allEquipment.map((equipment) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CategoryChip(
                                    label:
                                        equipment[0].toUpperCase() +
                                        equipment.substring(1),
                                    isSelected: selectedEquipment == equipment,
                                    onTap: () => setEquipmentFilter(equipment),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${filteredExercises.length} exercises found',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ExerciseCard(exercise: filteredExercises[index]);
                      },
                      childCount: filteredExercises.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

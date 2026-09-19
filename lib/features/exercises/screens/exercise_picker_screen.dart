import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:fitness_app/features/exercises/models/exercise_target_classifier.dart';
import 'package:fitness_app/features/exercises/services/exercise_service.dart';
import 'package:flutter/material.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];
  final Set<String> _selectedIds = {};
  Set<String> _allEquipment = {};

  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedMuscleGroup = 'All';
  String? _selectedSubTarget;
  String? _selectedEquipment;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await ExerciseService.loadExercises();

    final equipmentSet = <String>{};
    for (final exercise in exercises) {
      if (exercise.equipment.isNotEmpty) {
        equipmentSet.add(exercise.equipment);
      }
    }

    setState(() {
      _exercises = exercises;
      _filteredExercises = exercises;
      _allEquipment = equipmentSet;
      _isLoading = false;
    });
  }

  void _filterExercises() {
    setState(() {
      _filteredExercises = _exercises.where((exercise) {
        final matchesQuery =
            _searchQuery.isEmpty ||
            exercise.name.toLowerCase().contains(_searchQuery) ||
            exercise.detailedTarget.toLowerCase().contains(_searchQuery) ||
            exercise.primaryMuscleGroup.toLowerCase().contains(_searchQuery) ||
            exercise.bodyPart.toLowerCase().contains(_searchQuery) ||
            exercise.target.toLowerCase().contains(_searchQuery);

        final matchesMuscleGroup =
            _selectedMuscleGroup == 'All' ||
            exercise.primaryMuscleGroup == _selectedMuscleGroup;

        final matchesSubTarget =
            _selectedSubTarget == null ||
            _selectedSubTarget!.startsWith('All') ||
            exercise.detailedTarget == _selectedSubTarget;

        final matchesEquipment =
            _selectedEquipment == null ||
            exercise.equipment.toLowerCase() ==
                _selectedEquipment!.toLowerCase();

        return matchesQuery &&
            matchesMuscleGroup &&
            matchesSubTarget &&
            matchesEquipment;
      }).toList();
    });
  }

  void _searchExercises(String query) {
    _searchQuery = query.toLowerCase().trim();
    _filterExercises();
  }

  void _setMuscleGroupFilter(String group) {
    setState(() {
      _selectedMuscleGroup = group;
      _selectedSubTarget = null;
    });
    _filterExercises();
  }

  void _setSubTargetFilter(String? subTarget) {
    setState(() {
      _selectedSubTarget = subTarget;
    });
    _filterExercises();
  }

  void _setEquipmentFilter(String? equipment) {
    setState(() {
      _selectedEquipment = equipment;
    });
    _filterExercises();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableSubTargets = ExerciseTargetData.subTargetsFor(
      _selectedMuscleGroup,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercises'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selectedIds.clear),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: _searchExercises,
                    decoration: InputDecoration(
                      hintText: 'Search exercise or target...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Muscle Group filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ExerciseTargetData.muscleGroups.map((group) {
                      final isSelected = _selectedMuscleGroup == group;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(group),
                          selected: isSelected,
                          onSelected: (_) => _setMuscleGroupFilter(group),
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
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Sub-target chips (e.g. Upper Chest, Mid Chest, Lower Chest)
                if (availableSubTargets.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: availableSubTargets.map((subTarget) {
                        final isSelected =
                            _selectedSubTarget == subTarget ||
                            (_selectedSubTarget == null &&
                                subTarget.startsWith('All'));
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(subTarget),
                            selected: isSelected,
                            onSelected: (_) {
                              _setSubTargetFilter(
                                subTarget.startsWith('All') ? null : subTarget,
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
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                // Equipment filter row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All Equipment'),
                          selected: _selectedEquipment == null,
                          onSelected: (_) => _setEquipmentFilter(null),
                        ),
                      ),
                      ..._allEquipment.map((equipment) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              equipment[0].toUpperCase() +
                                  equipment.substring(1),
                            ),
                            selected: _selectedEquipment == equipment,
                            onSelected: (_) => _setEquipmentFilter(equipment),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      final isSelected = _selectedIds.contains(exercise.id);

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: exercise.gifUrl.isNotEmpty
                                ? Image.asset(
                                    'assets/${exercise.gifUrl}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        const Icon(Icons.fitness_center),
                                  )
                                : const Icon(Icons.fitness_center),
                          ),
                        ),
                        title: Text(
                          exercise.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4, right: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: exercise.subTargetBadgeColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                exercise.detailedTarget.toUpperCase(),
                                style: TextStyle(
                                  color: exercise.subTargetBadgeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              exercise.equipment,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelection(exercise.id),
                        ),
                        onTap: () => _toggleSelection(exercise.id),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedIds.toList()),
            child: Text(
              'Add ${_selectedIds.length} Exercise${_selectedIds.length == 1 ? '' : 's'}',
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:fitness_app/features/routines/repositories/routine_repository.dart';
import 'package:flutter/foundation.dart';

class RoutineProvider extends ChangeNotifier {
  RoutineProvider({required this.repository}) {
    loadRoutines();
  }
  final RoutineRepository repository;

  List<WorkoutRoutine> _routines = [];
  bool _isLoading = false;

  List<WorkoutRoutine> get routines => _routines;
  bool get isLoading => _isLoading;

  Future<void> loadRoutines() async {
    _isLoading = true;
    notifyListeners();

    _routines = await repository.getRoutines();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveRoutine(WorkoutRoutine routine) async {
    await repository.saveRoutine(routine);
    await loadRoutines(); // Reload to ensure sync
  }

  Future<void> deleteRoutine(String routineId) async {
    await repository.deleteRoutine(routineId);
    await loadRoutines();
  }
}

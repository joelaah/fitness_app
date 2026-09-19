import 'package:fitness_app/features/routines/models/routine.dart';
import 'package:uuid/uuid.dart';

abstract class RoutineRepository {
  Future<List<WorkoutRoutine>> getRoutines();
  Future<void> saveRoutine(WorkoutRoutine routine);
  Future<void> deleteRoutine(String routineId);
}

class MemoryRoutineRepository implements RoutineRepository {
  final List<WorkoutRoutine> _routines = [];

  @override
  Future<List<WorkoutRoutine>> getRoutines() async {
    // Return a cloned list to prevent direct mutation bypassing the repository
    return _routines.map((r) => r.clone()).toList();
  }

  @override
  Future<void> saveRoutine(WorkoutRoutine routine) async {
    if (routine.id.isEmpty) {
      routine.id = const Uuid().v4();
    }
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      _routines[index] = routine.clone();
    } else {
      _routines.add(routine.clone());
    }
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    _routines.removeWhere((r) => r.id == routineId);
  }
}

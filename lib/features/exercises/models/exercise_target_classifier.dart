import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:fitness_app/features/exercises/models/exercise.dart';
import 'package:flutter/material.dart';

extension ExerciseTargetClassifier on Exercise {
  /// Primary high-level muscle group: Chest, Back, Shoulders, Arms, Legs, Core, Cardio, Other
  String get primaryMuscleGroup {
    final bp = bodyPart.toLowerCase();
    final tg = target.toLowerCase();

    if (bp == 'chest' || tg.contains('pect')) return 'Chest';
    if (bp == 'shoulders' || tg.contains('delt')) return 'Shoulders';
    if (bp == 'back' ||
        tg == 'lats' ||
        tg == 'upper back' ||
        tg == 'traps' ||
        tg == 'spine') {
      return 'Back';
    }
    if (bp == 'upper arms' ||
        bp == 'lower arms' ||
        tg == 'biceps' ||
        tg == 'triceps' ||
        tg == 'forearms') {
      return 'Arms';
    }
    if (bp == 'upper legs' ||
        bp == 'lower legs' ||
        tg == 'quads' ||
        tg == 'hamstrings' ||
        tg == 'glutes' ||
        tg == 'calves' ||
        tg == 'adductors' ||
        tg == 'abductors') {
      return 'Legs';
    }
    if (bp == 'waist' || tg == 'abs') return 'Core';
    if (bp == 'cardio' || tg.contains('cardio')) return 'Cardio';

    return 'Other';
  }

  /// Specific functional sub-target (e.g. Upper Chest, Lats, Side Delts, Quads)
  String get detailedTarget {
    final group = primaryMuscleGroup;
    final n = name.toLowerCase();
    final tg = target.toLowerCase();

    switch (group) {
      case 'Chest':
        if (n.contains('stretch')) return 'Chest Mobility';
        if (n.contains('incline') ||
            n.contains('low to high') ||
            n.contains('low-to-high') ||
            n.contains('reverse grip bench') ||
            n.contains('incline fly') ||
            n.contains('incline push')) {
          return 'Upper Chest';
        }
        if (n.contains('decline') ||
            n.contains('dip') ||
            n.contains('high to low') ||
            n.contains('high-to-low') ||
            n.contains('underhand cable')) {
          return 'Lower Chest';
        }
        return 'Mid Chest';

      case 'Shoulders':
        if (n.contains('rear') ||
            n.contains('reverse') ||
            n.contains('face pull') ||
            n.contains('bent over lateral') ||
            n.contains('posterior')) {
          return 'Rear Delts';
        }
        if (n.contains('lateral') ||
            n.contains('side') ||
            n.contains('upright row')) {
          return 'Side Delts';
        }
        if (n.contains('front') ||
            n.contains('overhead') ||
            n.contains('press') ||
            n.contains('military') ||
            n.contains('arnold')) {
          return 'Front Delts';
        }
        return 'Shoulders';

      case 'Back':
        if (tg == 'lats' ||
            n.contains('lat') ||
            n.contains('pull-up') ||
            n.contains('chin-up') ||
            n.contains('pulldown')) {
          return 'Lats';
        }
        if (tg == 'spine' ||
            n.contains('hyperextension') ||
            n.contains('back extension') ||
            n.contains('good morning') ||
            n.contains('deadlift')) {
          return 'Lower Back';
        }
        if (tg == 'traps' || n.contains('shrug')) {
          return 'Traps';
        }
        return 'Upper Back';

      case 'Arms':
        if (tg == 'biceps' || n.contains('curl') || n.contains('bicep')) {
          return 'Biceps';
        }
        if (tg == 'triceps' ||
            n.contains('tricep') ||
            n.contains('extension') ||
            n.contains('skull') ||
            n.contains('pushdown') ||
            n.contains('kickback')) {
          return 'Triceps';
        }
        return 'Forearms';

      case 'Legs':
        if (tg == 'quads' ||
            n.contains('squat') ||
            n.contains('leg press') ||
            n.contains('lunge') ||
            n.contains('quad') ||
            n.contains('leg extension')) {
          return 'Quads';
        }
        if (tg == 'hamstrings' ||
            n.contains('hamstring') ||
            n.contains('leg curl') ||
            n.contains('romanian') ||
            n.contains('rdl') ||
            n.contains('stiff leg')) {
          return 'Hamstrings';
        }
        if (tg == 'glutes' ||
            tg == 'adductors' ||
            tg == 'abductors' ||
            n.contains('glute') ||
            n.contains('hip thrust') ||
            n.contains('bridge')) {
          return 'Glutes';
        }
        if (tg == 'calves' ||
            n.contains('calf') ||
            n.contains('calves') ||
            n.contains('raise')) {
          return 'Calves';
        }
        return 'Legs';

      case 'Core':
        if (n.contains('oblique') ||
            n.contains('twist') ||
            n.contains('side')) {
          return 'Obliques';
        }
        if (n.contains('plank') ||
            n.contains('hold') ||
            n.contains('rollout') ||
            n.contains('vacuum')) {
          return 'Core Stability';
        }
        return 'Abs';

      case 'Cardio':
        return 'Cardio';

      default:
        return target.isNotEmpty
            ? (target[0].toUpperCase() + target.substring(1))
            : bodyPart;
    }
  }

  /// Visual badge color tailored for the muscle group
  Color get subTargetBadgeColor {
    switch (primaryMuscleGroup) {
      case 'Chest':
        return const Color(0xFFE53935); // Crimson Red
      case 'Back':
        return const Color(0xFF1E88E5); // Ocean Blue
      case 'Shoulders':
        return const Color(0xFFFB8C00); // Amber Orange
      case 'Arms':
        return const Color(0xFF8E24AA); // Purple
      case 'Legs':
        return const Color(0xFF43A047); // Emerald Green
      case 'Core':
        return const Color(0xFF00ACC1); // Cyan
      case 'Cardio':
        return const Color(0xFFFFB300); // Gold
      default:
        return AppColors.primary;
    }
  }
}

class ExerciseTargetData {
  static const List<String> muscleGroups = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Cardio',
  ];

  static List<String> subTargetsFor(String group) {
    switch (group) {
      case 'Chest':
        return ['All Chest', 'Upper Chest', 'Mid Chest', 'Lower Chest'];
      case 'Back':
        return ['All Back', 'Lats', 'Upper Back', 'Traps', 'Lower Back'];
      case 'Shoulders':
        return ['All Shoulders', 'Front Delts', 'Side Delts', 'Rear Delts'];
      case 'Arms':
        return ['All Arms', 'Biceps', 'Triceps', 'Forearms'];
      case 'Legs':
        return ['All Legs', 'Quads', 'Hamstrings', 'Glutes', 'Calves'];
      case 'Core':
        return ['All Core', 'Abs', 'Obliques', 'Core Stability'];
      default:
        return [];
    }
  }
}

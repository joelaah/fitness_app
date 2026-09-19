import 'package:fitness_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RoutineVisualStyle {
  const RoutineVisualStyle({
    required this.coverGradient,
    required this.icon,
    this.imageAsset,
  });

  final List<Color> coverGradient;
  final IconData icon;
  final String? imageAsset;

  static const ppl = RoutineVisualStyle(
    coverGradient: AppColors.coverPush,
    icon: Icons.repeat,
    imageAsset: 'assets/images/cover_ppl.jpg',
  );

  static const upperLower = RoutineVisualStyle(
    coverGradient: AppColors.coverUpper,
    icon: Icons.layers,
    imageAsset: 'assets/images/cover_upper_lower.jpg',
  );

  static const arnold = RoutineVisualStyle(
    coverGradient: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
    icon: Icons.fitness_center,
    imageAsset: 'assets/images/cover_arnold.jpg',
  );

  static const broSplit = RoutineVisualStyle(
    coverGradient: [Color(0xFFD35400), Color(0xFF2C3E50)],
    icon: Icons.military_tech,
    imageAsset: 'assets/images/cover_bro_split.png',
  );

  static const fullBody = RoutineVisualStyle(
    coverGradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    icon: Icons.accessibility_new,
    imageAsset: 'assets/images/cover_full_body.jpg',
  );

  static const push = RoutineVisualStyle(
    coverGradient: AppColors.coverPush,
    icon: Icons.fitness_center,
    imageAsset: 'assets/images/cover_ppl.jpg',
  );

  static const pull = RoutineVisualStyle(
    coverGradient: AppColors.coverPull,
    icon: Icons.arrow_downward,
  );

  static const legs = RoutineVisualStyle(
    coverGradient: AppColors.coverLegs,
    icon: Icons.directions_run,
  );

  static const upper = RoutineVisualStyle(
    coverGradient: AppColors.coverUpper,
    icon: Icons.accessibility_new,
    imageAsset: 'assets/images/cover_upper_lower.jpg',
  );

  static const lower = RoutineVisualStyle(
    coverGradient: AppColors.coverLower,
    icon: Icons.airline_seat_legroom_extra,
    imageAsset: 'assets/images/cover_upper_lower.jpg',
  );

  static const defaultStyle = RoutineVisualStyle(
    coverGradient: AppColors.coverDefault,
    icon: Icons.sports_gymnastics,
  );
}

class RoutineThemeResolver {
  static RoutineVisualStyle resolve(String routineName) {
    final name = routineName.toLowerCase();

    if (name.contains('arnold')) return RoutineVisualStyle.arnold;
    if (name.contains('bro')) return RoutineVisualStyle.broSplit;
    if (name.contains('full body') || name.contains('fullbody')) {
      return RoutineVisualStyle.fullBody;
    }
    if (name.contains('upper') ||
        name.contains('lower') ||
        name.contains('phul') ||
        name.contains('torso') ||
        name.contains('limb')) {
      return RoutineVisualStyle.upperLower;
    }
    if (name.contains('ppl') || name.contains('push')) {
      return RoutineVisualStyle.ppl;
    }
    if (name.contains('pull')) return RoutineVisualStyle.pull;
    if (name.contains('leg')) return RoutineVisualStyle.legs;

    return RoutineVisualStyle.defaultStyle;
  }
}

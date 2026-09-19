import 'dart:io';

void main() async {
  final libDir = Directory('lib');

  final fileMappings = <String, String>{
    'lib/models/exercise.dart': 'lib/features/exercises/models/exercise.dart',
    'lib/service/exercise_service.dart':
        'lib/features/exercises/services/exercise_service.dart',
    'lib/screens/exercise_library_screen.dart':
        'lib/features/exercises/screens/exercise_library_screen.dart',
    'lib/screens/exercise_detail_screen.dart':
        'lib/features/exercises/screens/exercise_detail_screen.dart',
    'lib/screens/exercise_picker_screen.dart':
        'lib/features/exercises/screens/exercise_picker_screen.dart',
    'lib/widgets/exercise_card.dart':
        'lib/features/exercises/widgets/exercise_card.dart',
    'lib/widgets/exercise_thumbnail.dart':
        'lib/features/exercises/widgets/exercise_thumbnail.dart',

    'lib/models/routine.dart': 'lib/features/routines/models/routine.dart',
    'lib/providers/routine_provider.dart':
        'lib/features/routines/providers/routine_provider.dart',
    'lib/repositories/routine_repository.dart':
        'lib/features/routines/repositories/routine_repository.dart',
    'lib/repositories/shared_prefs_routine_repository.dart':
        'lib/features/routines/repositories/shared_prefs_routine_repository.dart',
    'lib/data/routine_templates.dart':
        'lib/features/routines/data/routine_templates.dart',
    'lib/screens/routines_screen.dart':
        'lib/features/routines/screens/routines_screen.dart',
    'lib/screens/routine_detail_screen.dart':
        'lib/features/routines/screens/routine_detail_screen.dart',
    'lib/screens/workout_day_screen.dart':
        'lib/features/routines/screens/workout_day_screen.dart',
    'lib/widgets/routine_cover_card.dart':
        'lib/features/routines/widgets/routine_cover_card.dart',

    'lib/theme/app_colors.dart': 'lib/core/theme/app_colors.dart',
    'lib/theme/app_spacing.dart': 'lib/core/theme/app_spacing.dart',
    'lib/theme/app_theme.dart': 'lib/core/theme/app_theme.dart',
    'lib/theme/routine_theme_resolver.dart':
        'lib/core/theme/routine_theme_resolver.dart',
    'lib/widgets/animated_tap_card.dart':
        'lib/core/widgets/animated_tap_card.dart',
    'lib/widgets/app_surface.dart': 'lib/core/widgets/app_surface.dart',
  };

  // Convert old import patterns to new package imports
  final importReplacements = <RegExp, String>{};
  for (final entry in fileMappings.entries) {
    final oldPath = entry.key.replaceFirst('lib/', '');
    final newPath = entry.value.replaceFirst('lib/', '');
    final packageImport = "import 'package:fitness_app/$newPath';";

    final filename = oldPath.split('/').last;

    // Catch relative imports like import '../models/exercise.dart'; or import 'models/exercise.dart';
    // We use a regex to match the filename and anything before it inside the quotes
    // e.g. import '.*?/exercise.dart'; or import 'exercise.dart';
    importReplacements[RegExp(r"import\s+'[^']*?" + filename + r"'\s*;")] =
        packageImport;
  }

  // 1. Move files
  for (final entry in fileMappings.entries) {
    final oldFile = File(entry.key);
    final newFile = File(entry.value);

    if (await oldFile.exists()) {
      await newFile.parent.create(recursive: true);
      await oldFile.rename(newFile.path);
      print('Moved ${entry.key} to ${entry.value}');
    }
  }

  // 2. Rewrite imports in all Dart files
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in dartFiles) {
    var content = await file.readAsString();
    var changed = false;

    for (final replacement in importReplacements.entries) {
      if (replacement.key.hasMatch(content)) {
        content = content.replaceAll(replacement.key, replacement.value);
        changed = true;
      }
    }

    if (changed) {
      await file.writeAsString(content);
      print('Updated imports in ${file.path}');
    }
  }

  // Also update test files if they exist
  final testDir = Directory('test');
  if (await testDir.exists()) {
    final testFiles = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in testFiles) {
      var content = await file.readAsString();
      var changed = false;
      for (final replacement in importReplacements.entries) {
        if (replacement.key.hasMatch(content)) {
          content = content.replaceAll(replacement.key, replacement.value);
          changed = true;
        }
      }
      if (changed) {
        await file.writeAsString(content);
        print('Updated imports in ${file.path}');
      }
    }
  }
}

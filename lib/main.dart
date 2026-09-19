import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Ensure widget binding is initialized before calling async plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if credentials are provided
  if (SupabaseConfig.isConfigured) {
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      SupabaseConfig.isInitialized = true;

      // Auto-create anonymous user if not signed in.
      // This gives each device its own Supabase user ID for cloud sync
      // and per-user AI recommendations without requiring email sign-up.
      // Requires: Supabase Dashboard → Authentication → Providers → Anonymous → Enable
      if (Supabase.instance.client.auth.currentUser == null) {
        await Supabase.instance.client.auth.signInAnonymously();
        debugPrint('Anonymous user created: '
            '${Supabase.instance.client.auth.currentUser?.id}');
      }
    } on Exception catch (e) {
      debugPrint('Supabase initialization notice: $e');
    }
  }

  // Initialize SharedPreferences asynchronously before runApp
  final prefs = await SharedPreferences.getInstance();
  final routineRepository = SharedPrefsRoutineRepository(prefs);
  final historyRepository = WorkoutHistoryRepository(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RoutineProvider(repository: routineRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(historyRepository: historyRepository),
        ),
      ],
      child: const FitnessApp(),
    ),
  );
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aura Fit',
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

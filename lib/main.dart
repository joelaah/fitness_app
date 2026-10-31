import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_event.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/chat/bloc/chat_bloc.dart';
import 'package:fitness_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Ensure widget binding is initialized before calling async plugins
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Parallelize SharedPreferences and Supabase initialization
  final prefsFuture = SharedPreferences.getInstance();
  final supabaseFuture = SupabaseConfig.isConfigured
      ? Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          // ignore: deprecated_member_use -- anonKey backwards compatibility
          anonKey: SupabaseConfig.supabaseAnonKey,
        ).then<Supabase?>((supabase) {
          SupabaseConfig.isInitialized = true;
          // Non-blocking background session check / anonymous sign-in
          // Requires: Supabase Dashboard → Authentication → Providers → Anonymous → Enable
          final authService = AuthService(client: supabase.client);
          if (authService.currentUser == null) {
            authService.signInAnonymously().then((_) {
              debugPrint('Anonymous user session established: '
                  '${authService.currentUserId}');
            }).catchError((Object e) {
              debugPrint('Background anonymous auth notice: $e');
            });
          }
          return supabase;
        }).catchError((Object e) {
          debugPrint('Supabase initialization notice: $e');
          return null;
        })
      : Future<Supabase?>.value(null);

  final results = await Future.wait([prefsFuture, supabaseFuture]);
  final prefs = results[0] as SharedPreferences;

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
    return MultiBlocProvider(
      providers: [
        BlocProvider<AiCoachBloc>(
          create: (ctx) {
            final workoutProvider = ctx.read<WorkoutProvider>();
            return AiCoachBloc()
              ..add(AiCoachRecommendationsRequested(
                sessions: workoutProvider.historyRepository.getAll(),
              ));
          },
        ),
        BlocProvider<ChatBloc>(
          create: (_) => ChatBloc(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PulseFit AI',
        theme: AppTheme.darkTheme,
        home: const MainScreen(),
      ),
    );
  }
}

import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/features/auth/screens/login_screen.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/workout/bloc/ai_coach_bloc.dart';
import 'package:fitness_app/features/workout/providers/workout_provider.dart';
import 'package:fitness_app/features/workout/repositories/workout_history_repository.dart';
import 'package:fitness_app/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

extension on WidgetTester {
  Future<void> pumpAndAdvance([
    Duration duration = const Duration(milliseconds: 300),
  ]) async {
    await pump();
    await pump(duration);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsRoutineRepository routineRepository;
  late WorkoutHistoryRepository historyRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    routineRepository = SharedPrefsRoutineRepository(prefs);
    historyRepository = WorkoutHistoryRepository(prefs);
  });

  Widget buildTestableMainScreen({AuthService? authService, int initialIndex = 0}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RoutineProvider(repository: routineRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(
            historyRepository: historyRepository,
          ),
        ),
      ],
      child: BlocProvider<AiCoachBloc>(
        create: (_) => AiCoachBloc(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MainScreen(
            initialIndex: initialIndex,
            authService: authService,
          ),
        ),
      ),
    );
  }

  group('PulseFit Login Entry Point & LoginScreen Tests', () {
    testWidgets('anonymous_user_sees_sign_in_button_in_header', (tester) async {
      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      expect(find.byKey(const Key('header_sign_in_button')), findsOneWidget);
      expect(find.byKey(const Key('header_profile_avatar')), findsNothing);
    });

    testWidgets('sign_in_button_opens_login_screen', (tester) async {
      final authService = AuthService();
      await authService.signInAnonymously();

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      final signInButton = find.byKey(const Key('header_sign_in_button'));
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('PulseFit AI'), findsOneWidget);
    });

    testWidgets('login_screen_has_google_apple_email_options', (tester) async {
      final authService = AuthService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LoginScreen(authService: authService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_continue_with_google')), findsOneWidget);
      expect(find.byKey(const Key('login_continue_with_apple')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'you@example.com'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Minimum 6 characters'), findsOneWidget);
    });

    testWidgets('authenticated_user_sees_profile_icon_not_sign_in', (tester) async {
      final verifiedUser = User(
        id: 'verified-user-123',
        email: 'athlete@pulsefit.ai',
        appMetadata: const {'provider': 'email'},
        userMetadata: const {'display_name': 'Verified Athlete'},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );

      final authService = AuthService(initialUser: verifiedUser);
      expect(authService.isAnonymous, isFalse);

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      expect(find.byKey(const Key('header_profile_avatar')), findsOneWidget);
      expect(find.byKey(const Key('header_sign_in_button')), findsNothing);
    });
  });
}

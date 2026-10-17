import 'dart:async';
import 'dart:typed_data';

import 'package:fitness_app/core/theme/app_theme.dart';
import 'package:fitness_app/features/auth/screens/auth_upgrade_dialog.dart';
import 'package:fitness_app/features/auth/screens/login_screen.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/auth/widgets/guest_expiration_banner.dart';
import 'package:fitness_app/features/routines/providers/routine_provider.dart';
import 'package:fitness_app/features/routines/repositories/shared_prefs_routine_repository.dart';
import 'package:fitness_app/features/trainers/models/trainer_profile.dart';
import 'package:fitness_app/features/trainers/screens/trainer_registration_screen.dart';
import 'package:fitness_app/features/trainers/services/certification_picker_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_service.dart';
import 'package:fitness_app/features/trainers/services/trainer_storage_service.dart';
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

class _ChallengerMockTrainerService extends TrainerService {
  @override
  Future<TrainerProfile> registerTrainer({
    required String bio,
    required List<String> certifications,
    required List<String> specialties,
    required int experienceYears,
    required double hourlyRate,
    String? userId,
    String? displayName,
    Map<String, dynamic>? availability,
  }) async {
    return TrainerProfile(
      id: 'challenger-reg-1',
      userId: userId ?? 'challenger-user-1',
      displayName: displayName ?? 'Coach Challenger',
      bio: bio,
      certifications: certifications,
      specialties: specialties,
      experienceYears: experienceYears,
      hourlyRate: hourlyRate,
    );
  }
}

class _ChallengerMockStorageService extends TrainerStorageService {
  @override
  Future<String> uploadCertification({
    required String userId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    return 'https://storage.pulsefit.ai/$userId/$fileName';
  }
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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

  Widget buildTestableMainScreen({
    AuthService? authService,
    int initialIndex = 0,
  }) {
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

  group('Bug 2 Empirical Verification: Auth State Transitions & UI Re-rendering', () {
    test('upgradeAnonymousUser immediately flips isAnonymous to false and clears TTL', () async {
      final authService = AuthService();
      await authService.signInAnonymously();

      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNotNull);
      expect(authService.isGuestExpired, isFalse);

      final response = await authService.upgradeAnonymousUser(
        email: 'athlete@pulsefit.ai',
        password: 'Password123!',
        displayName: 'Verified Athlete',
      );

      expect(response.user, isNotNull);
      expect(authService.isAnonymous, isFalse);
      expect(authService.guestExpirationTime, isNull);
      expect(authService.isGuestExpired, isFalse);
    });

    test('signOut resets _upgradeRequested to false and reverts isAnonymous to true', () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);

      await authService.upgradeAnonymousUser(
        email: 'coach@pulsefit.ai',
        password: 'Password123!',
        displayName: 'Coach Taylor',
      );
      expect(authService.isAnonymous, isFalse);

      // Sign out
      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(authService.isAnonymous, isTrue);

      // Sign in anonymously again
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNotNull);
    });

    testWidgets('GuestExpirationBanner re-renders without guest warnings after upgrade', (tester) async {
      _setMobileViewport(tester);

      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GuestExpirationBanner(authService: authService),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially banner must be present
      expect(find.byKey(const Key('guest_expiration_banner')), findsOneWidget);
      expect(find.text('Guest Session Expiring'), findsOneWidget);

      // Perform account upgrade via dialog
      final saveBtn = find.byKey(const Key('guest_expiration_banner_action'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AuthUpgradeDialog), findsOneWidget);

      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Jordan Peak');

      final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'jordan@pulsefit.ai');

      final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'pass123456');

      final submitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.byType(AuthUpgradeDialog), findsNothing);

      // Banner is reactively gone
      expect(find.byKey(const Key('guest_expiration_banner')), findsNothing);
      expect(find.text('Guest Session Expiring'), findsNothing);
      expect(authService.isAnonymous, isFalse);
    });

    testWidgets('TrainerRegistrationScreen re-renders without anonymous guest warning card', (tester) async {
      _setMobileViewport(tester);

      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: TrainerRegistrationScreen(
            authService: authService,
            trainerService: _ChallengerMockTrainerService(),
            storageService: _ChallengerMockStorageService(),
            pickerService: CertificationPickerService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initially "Anonymous Session Detected" card is visible
      expect(find.text('Anonymous Session Detected'), findsOneWidget);
      expect(find.text('You must upgrade to a permanent account.'), findsOneWidget);

      // 2. Tap Upgrade button on that card
      final upgradeBtn = find.widgetWithText(TextButton, 'Upgrade');
      expect(upgradeBtn, findsOneWidget);
      await tester.tap(upgradeBtn);
      await tester.pumpAndSettle();

      // 3. Complete upgrade dialog
      expect(find.byType(AuthUpgradeDialog), findsOneWidget);

      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Morgan Fitness');

      final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'morgan@pulsefit.ai');

      final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'morgancertpass1');

      final submitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // 4. Dialog is dismissed
      expect(find.byType(AuthUpgradeDialog), findsNothing);

      // 5. Success SnackBar was presented
      expect(find.text('Account upgraded! You may now publish your coach profile.'), findsOneWidget);

      // 6. "Anonymous Session Detected" card is completely gone!
      expect(find.text('Anonymous Session Detected'), findsNothing);
      expect(find.text('You must upgrade to a permanent account.'), findsNothing);
      expect(authService.isAnonymous, isFalse);
    });
  });

  group('Bug 4 Empirical Verification: Header, LoginScreen & Reactive Sign Out', () {
    testWidgets('anonymous user sees header_sign_in_button, tapping opens LoginScreen', (tester) async {
      _setMobileViewport(tester);
      final authService = AuthService();
      await authService.signInAnonymously();

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      // Anonymous header shows sign in button
      final signInBtn = find.byKey(const Key('header_sign_in_button'));
      expect(signInBtn, findsOneWidget);
      expect(find.byKey(const Key('header_profile_avatar')), findsNothing);

      // Tapping opens LoginScreen
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_continue_with_google')), findsOneWidget);
      expect(find.byKey(const Key('login_continue_with_apple')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    });

    testWidgets('authenticated user sees header_profile_avatar with popup menu (Profile, Sign Out)', (tester) async {
      _setMobileViewport(tester);
      final authService = AuthService();
      await authService.signUpWithEmail(
        email: 'authenticated@pulsefit.ai',
        password: 'Password123!',
        displayName: 'Auth Athlete',
      );
      expect(authService.isAnonymous, isFalse);

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      expect(find.byKey(const Key('header_profile_avatar')), findsOneWidget);
      expect(find.byKey(const Key('header_sign_in_button')), findsNothing);

      // Tap profile avatar to trigger popup menu
      await tester.tap(find.byKey(const Key('header_profile_avatar')));
      await tester.pumpAndAdvance(const Duration(milliseconds: 300));

      // Verify popup menu items
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('selecting Sign Out in popup menu reverts header to header_sign_in_button reactively', (tester) async {
      _setMobileViewport(tester);
      final authService = AuthService();
      await authService.signUpWithEmail(
        email: 'signout.user@pulsefit.ai',
        password: 'Password123!',
        displayName: 'SignOut User',
      );
      expect(authService.isAnonymous, isFalse);

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      expect(find.byKey(const Key('header_profile_avatar')), findsOneWidget);
      expect(find.byKey(const Key('header_sign_in_button')), findsNothing);

      // Open popup menu
      await tester.tap(find.byKey(const Key('header_profile_avatar')));
      await tester.pumpAndAdvance(const Duration(milliseconds: 300));

      // Tap Sign Out
      final signOutItem = find.text('Sign Out');
      expect(signOutItem, findsOneWidget);
      await tester.tap(signOutItem);
      await tester.pumpAndAdvance(const Duration(milliseconds: 300));

      // Verify authService is now signed out and isAnonymous is true
      expect(authService.currentUser, isNull);
      expect(authService.isAnonymous, isTrue);

      // Header must reactively revert to header_sign_in_button
      expect(find.byKey(const Key('header_sign_in_button')), findsOneWidget);
      expect(find.byKey(const Key('header_profile_avatar')), findsNothing);
    });

    testWidgets('stream onAuthStateChange reactively updates header from Sign In to Profile Avatar', (tester) async {
      _setMobileViewport(tester);
      final authStreamController = StreamController<AuthState>.broadcast();
      addTearDown(authStreamController.close);

      final authService = AuthService(
        authStateStream: authStreamController.stream,
      );
      await authService.signInAnonymously();
      expect(authService.isAnonymous, isTrue);

      await tester.pumpWidget(buildTestableMainScreen(authService: authService));
      await tester.pumpAndAdvance();

      // Initially anonymous
      expect(find.byKey(const Key('header_sign_in_button')), findsOneWidget);
      expect(find.byKey(const Key('header_profile_avatar')), findsNothing);

      // Simulate external auth change (e.g. user finished OAuth or logged in)
      await authService.upgradeAnonymousUser(
        email: 'stream.user@pulsefit.ai',
        password: 'Password123!',
        displayName: 'Stream Athlete',
      );
      // Emit auth state change through the stream
      authStreamController.add(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'mock-stream-token',
            tokenType: 'bearer',
            user: authService.currentUser!,
          ),
        ),
      );
      await tester.pumpAndAdvance();

      // Header reactively switched to profile avatar
      expect(find.byKey(const Key('header_profile_avatar')), findsOneWidget);
      expect(find.byKey(const Key('header_sign_in_button')), findsNothing);
    });
  });
}

import 'dart:async';

import 'package:fitness_app/features/auth/screens/auth_upgrade_dialog.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _buildTestableDialog({
  AuthService? authService,
  Future<bool> Function()? onGoogleSignIn,
  Future<bool> Function()? onAppleSignIn,
  Future<void> Function(String email, String password, String name)?
      onEmailSubmit,
  VoidCallback? onEmailPasswordPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (_) => AuthUpgradeDialog(
                  authService: authService,
                  onGoogleSignIn: onGoogleSignIn,
                  onAppleSignIn: onAppleSignIn,
                  onEmailSubmit: onEmailSubmit,
                  onEmailPasswordPressed: onEmailPasswordPressed,
                ),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
}

void _setStandardViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthUpgradeDialog UI Integration & Multi-Provider Options (R3)', () {
    testWidgets('renders Google, Apple, and Email options with 2-hour TTL notice',
        (tester) async {
      _setStandardViewport(tester);
      final authService = AuthService();
      await authService.signInAnonymously();

      await tester.pumpWidget(_buildTestableDialog(authService: authService));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Header & Badges
      expect(find.text('ACCOUNT UPGRADE'), findsOneWidget);
      expect(find.text('Save Your Workout History'), findsOneWidget);

      // 2-Hour Auto-Expiration Warning
      expect(find.text('2-Hour Auto-Expiration Policy'), findsOneWidget);
      expect(
        find.textContaining('Guest data auto-expires in 2 hours unless linked'),
        findsOneWidget,
      );

      // Multi-Provider Buttons
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Email & Password'), findsOneWidget);
    });

    testWidgets('tapping Continue with Google triggers Google auth callback',
        (tester) async {
      _setStandardViewport(tester);
      bool googleTriggered = false;

      await tester.pumpWidget(
        _buildTestableDialog(
          onGoogleSignIn: () async {
            googleTriggered = true;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(googleTriggered, isTrue);
      // Dialog should pop after successful Google OAuth
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets('tapping Continue with Apple triggers Apple auth callback',
        (tester) async {
      _setStandardViewport(tester);
      bool appleTriggered = false;

      await tester.pumpWidget(
        _buildTestableDialog(
          onAppleSignIn: () async {
            appleTriggered = true;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(appleTriggered, isTrue);
      // Dialog should pop after successful Apple OAuth
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets(
        'validates empty fields when Continue with Email & Password is clicked',
        (tester) async {
      _setStandardViewport(tester);
      bool emailPressed = false;

      await tester.pumpWidget(
        _buildTestableDialog(
          onEmailPasswordPressed: () {
            emailPressed = true;
          },
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pumpAndSettle();

      expect(emailPressed, isTrue);
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets(
        'submitting valid email credentials calls upgrade handler & closes dialog',
        (tester) async {
      _setStandardViewport(tester);
      String? submittedEmail;
      String? submittedPassword;
      String? submittedName;

      await tester.pumpWidget(
        _buildTestableDialog(
          onEmailSubmit: (email, password, name) async {
            submittedEmail = email;
            submittedPassword = password;
            submittedName = name;
          },
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter valid fields
      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Alex Mercer');

      final emailField =
          find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'alex@pulsefit.ai');

      final passwordField =
          find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'supersecret123');

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pumpAndSettle();

      expect(submittedName, 'Alex Mercer');
      expect(submittedEmail, 'alex@pulsefit.ai');
      expect(submittedPassword, 'supersecret123');
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets(
        'native AuthService email upgrade preserves guest UUID in dialog flow',
        (tester) async {
      _setStandardViewport(tester);
      final authService = AuthService();
      await authService.signInAnonymously();
      final initialUuid = authService.currentUserId;
      expect(initialUuid, isNotNull);

      await tester.pumpWidget(_buildTestableDialog(authService: authService));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Taylor Swiftfit');

      final emailField =
          find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'taylor@pulsefit.ai');

      final passwordField =
          find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'cardio123');

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pumpAndSettle();

      expect(authService.currentUserId, equals(initialUuid));
      expect(authService.isAnonymous, isFalse);
      expect(authService.currentUser?.email, 'taylor@pulsefit.ai');
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets('toggling between Upgrade and Sign In mode adjusts UI form',
        (tester) async {
      _setStandardViewport(tester);
      await tester.pumpWidget(_buildTestableDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Initial state: Upgrade mode
      expect(find.text('Save Your Workout History'), findsOneWidget);
      expect(find.text('Full Name / Coach Title'), findsOneWidget);
      expect(find.text('Continue with Email & Password'), findsOneWidget);

      // Switch to Sign In mode
      final switchBtn =
          find.text('Already have a registered account? Sign In');
      await tester.ensureVisible(switchBtn);
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sign In to Account'), findsOneWidget);
      expect(find.text('Full Name / Coach Title'), findsNothing);
      expect(find.text('Sign In with Email'), findsOneWidget);

      // Switch back to Upgrade mode
      final switchBackBtn =
          find.text("Don't have an account? Upgrade anonymous guest");
      await tester.ensureVisible(switchBackBtn);
      await tester.tap(switchBackBtn);
      await tester.pumpAndSettle();

      expect(find.text('Save Your Workout History'), findsOneWidget);
      expect(find.text('Full Name / Coach Title'), findsOneWidget);
    });

    testWidgets('close icon dismisses dialog without action', (tester) async {
      _setStandardViewport(tester);
      await tester.pumpWidget(_buildTestableDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthUpgradeDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets('rejects invalid email formats', (tester) async {
      _setStandardViewport(tester);
      await tester.pumpWidget(_buildTestableDialog());
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.ensureVisible(nameField);
      await tester.enterText(nameField, 'Alex Mercer');

      final emailField =
          find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'notanemail');

      final passwordField =
          find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'secret123');

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('static AuthUpgradeDialog.show passes onEmailPasswordPressed callback',
        (tester) async {
      _setStandardViewport(tester);
      bool emailPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AuthUpgradeDialog.show(
                    ctx,
                    onEmailPasswordPressed: () {
                      emailPressed = true;
                    },
                  );
                },
                child: const Text('Open Via Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Via Show'));
      await tester.pumpAndSettle();

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pumpAndSettle();

      expect(emailPressed, isTrue);
    });

    testWidgets('renders < 1 min remaining when TTL is under 60 seconds', (tester) async {
      _setStandardViewport(tester);
      final expiringUser = User(
        id: 'anon-sub-minute',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 59, seconds: 30)).toIso8601String(),
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: expiringUser);

      await tester.pumpWidget(_buildTestableDialog(authService: authService));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('< 1 min remaining'), findsOneWidget);
    });

    testWidgets('unsuccessful OAuth displays informative error message', (tester) async {
      _setStandardViewport(tester);
      await tester.pumpWidget(
        _buildTestableDialog(
          onGoogleSignIn: () async => false,
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Authentication could not be completed. Please try again.'), findsOneWidget);
      expect(find.byType(AuthUpgradeDialog), findsOneWidget);
    });

    testWidgets('text fields and close button are disabled while submit is loading', (tester) async {
      _setStandardViewport(tester);
      final completer = Completer<void>();

      await tester.pumpWidget(
        _buildTestableDialog(
          onEmailSubmit: (e, p, n) => completer.future,
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter valid fields
      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.enterText(nameField, 'Alex Mercer');
      final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.enterText(emailField, 'alex@pulsefit.ai');
      final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.enterText(passwordField, 'supersecret123');

      final emailSubmitBtn = find.text('Continue with Email & Password');
      await tester.ensureVisible(emailSubmitBtn);
      await tester.tap(emailSubmitBtn);
      await tester.pump(); // Start async work without settling

      // Verify close button is disabled
      final closeBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close));
      expect(closeBtn.onPressed, isNull);

      // Verify text field enabled is false
      final nameWidget = tester.widget<TextFormField>(nameField);
      expect(nameWidget.enabled, isFalse);

      // Verify password visibility toggle is disabled
      final visibilityBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.visibility_off));
      expect(visibilityBtn.onPressed, isNull);

      // Complete work
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });

    testWidgets('renders Guest Session Expired notice when guest session exceeds 2 hours',
        (tester) async {
      _setStandardViewport(tester);
      final expiredCreatedAt =
          DateTime.now().subtract(const Duration(hours: 2, minutes: 10));
      final expiredUser = User(
        id: 'anon-expired-dialog-user',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {'ttl_hours': 2},
        aud: 'authenticated',
        createdAt: expiredCreatedAt.toIso8601String(),
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: expiredUser);

      await tester.pumpWidget(_buildTestableDialog(authService: authService));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Guest Session Expired'), findsOneWidget);
      expect(
        find.textContaining('Your guest session has expired'),
        findsOneWidget,
      );
    });

    testWidgets('password field onFieldSubmitted triggers email submission',
        (tester) async {
      _setStandardViewport(tester);
      String? submittedEmail;
      String? submittedPassword;
      String? submittedName;

      await tester.pumpWidget(
        _buildTestableDialog(
          onEmailSubmit: (email, password, name) async {
            submittedEmail = email;
            submittedPassword = password;
            submittedName = name;
          },
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter valid fields
      final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
      await tester.enterText(nameField, 'Jordan Lifter');
      final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
      await tester.enterText(emailField, 'jordan@pulsefit.ai');
      final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
      await tester.enterText(passwordField, 'powerlifting99');

      // Submit using Enter / Done on password field
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submittedName, 'Jordan Lifter');
      expect(submittedEmail, 'jordan@pulsefit.ai');
      expect(submittedPassword, 'powerlifting99');
      expect(find.byType(AuthUpgradeDialog), findsNothing);
    });
  });
}

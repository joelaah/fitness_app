import 'package:fitness_app/features/auth/screens/auth_upgrade_dialog.dart';
import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestableDialog({
  AuthService? authService,
  Future<bool> Function()? onGoogleSignIn,
  Future<bool> Function()? onAppleSignIn,
  Future<void> Function(String email, String password, String name)?
      onEmailSubmit,
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

  group('Bug 3 Empirical Challenger: AutovalidateMode in AuthUpgradeDialog', () {
    testWidgets(
      'empirical_challenge_empty_submit_triggers_errors_and_typing_valid_chars_clears_instantly',
      (tester) async {
        _setStandardViewport(tester);
        await tester.pumpWidget(_buildTestableDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // 1. Initial state: verify NO error messages are present
        expect(find.text('Please enter your name'), findsNothing);
        expect(find.text('Please enter your email'), findsNothing);
        expect(find.text('Please enter a password'), findsNothing);

        // 2. Submit empty form
        final emailSubmitBtn = find.text('Continue with Email & Password');
        await tester.ensureVisible(emailSubmitBtn);
        await tester.tap(emailSubmitBtn);
        await tester.pumpAndSettle();

        // 3. Verify all validation errors appear
        expect(find.text('Please enter your name'), findsOneWidget);
        expect(find.text('Please enter your email'), findsOneWidget);
        expect(find.text('Please enter a password'), findsOneWidget);

        // 4. Enter valid Name: error disappears on keystroke without submit click
        final nameField = find.widgetWithText(TextFormField, 'e.g. Alex Mercer');
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Jane Doe');
        await tester.pump();
        expect(find.text('Please enter your name'), findsNothing,
            reason: 'Name error must clear instantly on valid input');

        // 5. Enter valid Email: error disappears on keystroke without submit click
        final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
        await tester.ensureVisible(emailField);
        await tester.enterText(emailField, 'jane@pulsefit.ai');
        await tester.pump();
        expect(find.text('Please enter your email'), findsNothing,
            reason: 'Email empty error must clear instantly on valid input');
        expect(find.text('Enter a valid email'), findsNothing,
            reason: 'Email format error must not be triggered');

        // 6. Enter valid Password: error disappears on keystroke without submit click
        final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
        await tester.ensureVisible(passwordField);
        await tester.enterText(passwordField, 'secretPass123');
        await tester.pump();
        expect(find.text('Please enter a password'), findsNothing,
            reason: 'Password error must clear instantly on valid input');
        expect(find.text('Password must be at least 6 characters'), findsNothing,
            reason: 'Length error must not be triggered');

        // All errors completely cleared with ZERO re-submissions
        expect(find.text('Please enter your name'), findsNothing);
        expect(find.text('Please enter your email'), findsNothing);
        expect(find.text('Please enter a password'), findsNothing);
      },
    );

    testWidgets(
      'empirical_challenge_invalid_email_format_persists_then_clears_instantly_on_domain_completion',
      (tester) async {
        _setStandardViewport(tester);
        await tester.pumpWidget(_buildTestableDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Submit empty form to activate validation
        final emailSubmitBtn = find.text('Continue with Email & Password');
        await tester.ensureVisible(emailSubmitBtn);
        await tester.tap(emailSubmitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Please enter your email'), findsOneWidget);

        final emailField = find.widgetWithText(TextFormField, 'coach@example.com');
        await tester.ensureVisible(emailField);

        // Step A: Type invalid format "not-an-email"
        await tester.enterText(emailField, 'not-an-email');
        await tester.pump();

        // "Please enter your email" changes to "Enter a valid email"
        expect(find.text('Please enter your email'), findsNothing);
        expect(find.text('Enter a valid email'), findsOneWidget,
            reason: 'Invalid email format error must persist while typing invalid text');

        // Step B: Type partially completed email "not-an-email@"
        await tester.enterText(emailField, 'not-an-email@');
        await tester.pump();
        expect(find.text('Enter a valid email'), findsOneWidget);

        // Step C: Complete domain with "@test.com" -> "not-an-email@test.com"
        await tester.enterText(emailField, 'not-an-email@test.com');
        await tester.pump();

        // Step D: Verify error clears instantly WITHOUT clicking submit
        expect(find.text('Enter a valid email'), findsNothing,
            reason: 'Email error must clear instantly when valid domain is typed');
        expect(find.text('Please enter your email'), findsNothing);
      },
    );

    testWidgets(
      'empirical_challenge_password_length_boundary_clearing',
      (tester) async {
        _setStandardViewport(tester);
        await tester.pumpWidget(_buildTestableDialog());
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Submit empty form to trigger error
        final emailSubmitBtn = find.text('Continue with Email & Password');
        await tester.ensureVisible(emailSubmitBtn);
        await tester.tap(emailSubmitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a password'), findsOneWidget);

        final passwordField = find.widgetWithText(TextFormField, 'Minimum 6 characters');
        await tester.ensureVisible(passwordField);

        // Step A: Boundary 5 characters -> fails min length
        await tester.enterText(passwordField, '12345');
        await tester.pump();
        expect(find.text('Password must be at least 6 characters'), findsOneWidget);

        // Step B: Boundary 6 characters -> satisfies validator immediately
        await tester.enterText(passwordField, '123456');
        await tester.pump();
        expect(find.text('Password must be at least 6 characters'), findsNothing,
            reason: '6-character password must clear error immediately on 6th keystroke');
        expect(find.text('Please enter a password'), findsNothing);

        // Step C: Deleting back to 5 chars re-triggers error immediately
        await tester.enterText(passwordField, '12345');
        await tester.pump();
        expect(find.text('Password must be at least 6 characters'), findsOneWidget,
            reason: 'Deleting char below 6 must immediately re-display error under onUserInteraction');
      },
    );
  });
}

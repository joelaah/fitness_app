import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/auth/widgets/guest_expiration_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget _buildTestableBanner({
  required AuthService authService,
  VoidCallback? onUpgradeTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GuestExpirationBanner(
        authService: authService,
        onUpgradeTap: onUpgradeTap,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuestExpirationBanner In-App Expiration Warning (R1)', () {
    testWidgets('renders 2-hour auto-expiry warning for anonymous guest users',
        (tester) async {
      final authService = AuthService();
      await authService.signInAnonymously();

      await tester.pumpWidget(_buildTestableBanner(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guest_expiration_banner')), findsOneWidget);
      expect(find.text('Guest Session Expiring'), findsOneWidget);
      expect(
        find.text(
          'Your workout history will expire in 2 hours unless you save your account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save Account'), findsOneWidget);
    });

    testWidgets('tapping Save Account triggers upgrade callback',
        (tester) async {
      final authService = AuthService();
      await authService.signInAnonymously();
      bool upgradeTapped = false;

      await tester.pumpWidget(
        _buildTestableBanner(
          authService: authService,
          onUpgradeTap: () {
            upgradeTapped = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guest_expiration_banner_action')));
      await tester.pumpAndSettle();

      expect(upgradeTapped, isTrue);
    });

    testWidgets('renders expired notice when guest session exceeds 2 hours',
        (tester) async {
      final expiredCreatedAt =
          DateTime.now().subtract(const Duration(hours: 2, minutes: 10));
      final expiredUser = User(
        id: 'anon-expired-banner-user',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {'ttl_hours': 2},
        aud: 'authenticated',
        createdAt: expiredCreatedAt.toIso8601String(),
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: expiredUser);

      await tester.pumpWidget(_buildTestableBanner(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guest_expiration_banner')), findsOneWidget);
      expect(find.text('Guest Session Expired'), findsOneWidget);
      expect(
        find.text(
          'Your temporary guest data has expired. Save your account now to preserve remaining data.',
        ),
        findsOneWidget,
      );
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('renders nothing when session is not yet initialized',
        (tester) async {
      final authService = AuthService();

      await tester.pumpWidget(_buildTestableBanner(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guest_expiration_banner')), findsNothing);
    });

    testWidgets('renders nothing when user is authenticated / permanent',
        (tester) async {
      final permanentUser = User(
        id: 'permanent-athlete-001',
        email: 'athlete@pulsefit.ai',
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: const {'display_name': 'Sarah Connor'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        isAnonymous: false,
      );

      final authService = AuthService(initialUser: permanentUser);

      await tester.pumpWidget(_buildTestableBanner(authService: authService));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guest_expiration_banner')), findsNothing);
      expect(find.text('Guest Session Expiring'), findsNothing);
    });

    testWidgets('didUpdateWidget refreshes state when new authService is provided',
        (tester) async {
      final authService1 = AuthService();
      await authService1.signInAnonymously();

      await tester.pumpWidget(_buildTestableBanner(authService: authService1));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guest_expiration_banner')), findsOneWidget);

      // Now update to permanent user
      final permanentUser = User(
        id: 'permanent-athlete-002',
        email: 'athlete2@pulsefit.ai',
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: const {'display_name': 'John Connor'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        isAnonymous: false,
      );
      final authService2 = AuthService(initialUser: permanentUser);

      await tester.pumpWidget(_buildTestableBanner(authService: authService2));
      await tester.pumpAndSettle();

      // Banner should disappear
      expect(find.byKey(const Key('guest_expiration_banner')), findsNothing);
    });

    testWidgets('renders < 1 min badge when TTL is under 60 seconds', (tester) async {
      final expiringUser = User(
        id: 'anon-sub-minute-banner',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 59, seconds: 30)).toIso8601String(),
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: expiringUser);

      await tester.pumpWidget(_buildTestableBanner(authService: authService));
      await tester.pumpAndSettle();

      expect(find.text('< 1 min'), findsOneWidget);
    });
  });
}

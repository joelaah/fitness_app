import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Anonymous Session Lifecycle & 2-Hour Auto-Expiry (R1)', () {
    test('defaults to anonymous when no session is active', () {
      final authService = AuthService();
      expect(authService.currentUser, isNull);
      expect(authService.currentUserId, isNull);
      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNull);
      expect(authService.guestTimeRemaining, isNull);
      expect(authService.isGuestExpired, isFalse);
    });

    test('signInAnonymously establishes guest session with 2-hour TTL tagging',
        () async {
      final authService = AuthService();
      final beforeTime = DateTime.now();

      final response = await authService.signInAnonymously();

      expect(response.user, isNotNull);
      expect(authService.currentUser, isNotNull);
      expect(authService.isAnonymous, isTrue);
      expect(authService.currentUserId, startsWith('mock-anon-user-'));

      // Verify 2-hour TTL tagging in user metadata
      final metadata = authService.currentUser!.userMetadata;
      expect(metadata?['ttl_hours'], 2);
      expect(metadata?['expires_at'], isNotNull);
      expect((metadata?['expires_at'] as String).endsWith('Z'), isTrue);
      expect(authService.currentUser!.createdAt.endsWith('Z'), isTrue);

      // Verify expiration timestamp
      final expiration = authService.guestExpirationTime;
      expect(expiration, isNotNull);
      expect(
        expiration!.isAfter(beforeTime.add(const Duration(hours: 1, minutes: 59))),
        isTrue,
      );
      expect(
        expiration.isBefore(DateTime.now().add(const Duration(hours: 2, minutes: 1))),
        isTrue,
      );

      // Verify time remaining
      final remaining = authService.guestTimeRemaining;
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, inInclusiveRange(118, 120));
      expect(authService.isGuestExpired, isFalse);
    });

    test('guest session older than 2 hours is marked as expired', () {
      final oldCreatedAt =
          DateTime.now().subtract(const Duration(hours: 2, minutes: 15));
      final expiredUser = User(
        id: 'anon-expired-user-123',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {'ttl_hours': 2},
        aud: 'authenticated',
        createdAt: oldCreatedAt.toIso8601String(),
        isAnonymous: true,
      );

      final authService = AuthService(initialUser: expiredUser);

      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNotNull);
      expect(authService.guestTimeRemaining, Duration.zero);
      expect(authService.isGuestExpired, isTrue);
    });

    test('active guest session created 30 minutes ago has ~1.5h remaining', () {
      final thirtyMinsAgo = DateTime.now().subtract(const Duration(minutes: 30));
      final activeUser = User(
        id: 'anon-active-user-456',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {'ttl_hours': 2},
        aud: 'authenticated',
        createdAt: thirtyMinsAgo.toIso8601String(),
        isAnonymous: true,
      );

      final authService = AuthService(initialUser: activeUser);

      expect(authService.isAnonymous, isTrue);
      expect(authService.isGuestExpired, isFalse);
      expect(authService.guestTimeRemaining!.inMinutes, inInclusiveRange(88, 92));
    });

    test('permanent user does not have guest expiration or TTL window', () {
      final permanentUser = User(
        id: 'permanent-user-789',
        email: 'athlete@pulsefit.com',
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: const {'display_name': 'Champion'},
        aud: 'authenticated',
        createdAt: DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        isAnonymous: false,
      );

      final authService = AuthService(initialUser: permanentUser);

      expect(authService.isAnonymous, isFalse);
      expect(authService.guestExpirationTime, isNull);
      expect(authService.guestTimeRemaining, isNull);
      expect(authService.isGuestExpired, isFalse);
    });
  });

  group('AuthService Multi-Provider Account Upgrade (R2)', () {
    test('Google OAuth upgrade strictly preserves user UUID and clears guest status',
        () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      final initialUuid = authService.currentUserId;
      expect(initialUuid, isNotNull);
      expect(authService.isAnonymous, isTrue);

      // Perform Google OAuth upgrade
      final upgraded = await authService.linkWithGoogle();
      expect(upgraded, isTrue);

      // Verify UUID preservation
      expect(authService.currentUserId, equals(initialUuid));
      expect(authService.isAnonymous, isFalse);
      expect(authService.currentUser?.appMetadata['provider'], 'google');
      expect(authService.guestExpirationTime, isNull);
    });

    test('Apple OAuth upgrade strictly preserves user UUID and clears guest status',
        () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      final initialUuid = authService.currentUserId;
      expect(initialUuid, isNotNull);
      expect(authService.isAnonymous, isTrue);

      // Perform Apple OAuth upgrade
      final upgraded = await authService.linkWithApple();
      expect(upgraded, isTrue);

      // Verify UUID preservation
      expect(authService.currentUserId, equals(initialUuid));
      expect(authService.isAnonymous, isFalse);
      expect(authService.currentUser?.appMetadata['provider'], 'apple');
      expect(authService.guestExpirationTime, isNull);
    });

    test(
        'Email & password upgrade strictly preserves user UUID and syncs profile',
        () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      final initialUuid = authService.currentUserId;
      expect(initialUuid, isNotNull);
      expect(authService.isAnonymous, isTrue);

      // Perform Email & Password upgrade
      final response = await authService.upgradeAnonymousUser(
        email: 'alex.athlete@example.com',
        password: 'securePassword123',
        displayName: 'Alex Mercer',
      );

      expect(response.user, isNotNull);
      expect(response.user!.id, equals(initialUuid));
      expect(authService.currentUserId, equals(initialUuid));
      expect(authService.currentUser!.email, 'alex.athlete@example.com');
      expect(authService.isAnonymous, isFalse);
      expect(
        authService.currentUser!.userMetadata?['display_name'],
        'Alex Mercer',
      );
      expect(authService.guestExpirationTime, isNull);
    });

    test('linkWithEmail alias executes upgrade correctly', () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      final initialUuid = authService.currentUserId;

      final res = await authService.linkWithEmail(
        email: 'coach.dan@pulsefit.com',
        password: 'passWord456!',
        displayName: 'Dan Trainer',
      );

      expect(res.user?.id, equals(initialUuid));
      expect(authService.currentUser?.email, 'coach.dan@pulsefit.com');
      expect(authService.isAnonymous, isFalse);
    });
  });

  group('AuthService Permanent Sign-In and Session Reset', () {
    test('signInWithEmail logs in permanent account', () async {
      final authService = AuthService();
      final res = await authService.signInWithEmail(
        email: 'user@pulsefit.ai',
        password: 'password123',
      );
      expect(res.user, isNotNull);
      expect(authService.isAnonymous, isFalse);
      expect(authService.currentUser?.email, 'user@pulsefit.ai');
    });

    test('signUpWithEmail registers new permanent account', () async {
      final authService = AuthService();
      final res = await authService.signUpWithEmail(
        email: 'newuser@pulsefit.ai',
        password: 'password123',
        displayName: 'New Runner',
      );
      expect(res.user, isNotNull);
      expect(authService.isAnonymous, isFalse);
      expect(authService.currentUser?.email, 'newuser@pulsefit.ai');
    });

    test('guestExpirationTime safely returns null when user createdAt cannot be parsed', () {
      final user = User(
        id: 'anon-unparseable',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: 'invalid-date-format',
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: user);
      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNull);
      expect(authService.guestTimeRemaining, isNull);
      expect(authService.isGuestExpired, isFalse);
    });

    test('guestExpirationTime honors explicit expires_at from userMetadata', () {
      final customExpiry = DateTime.now().add(const Duration(hours: 2));
      final user = User(
        id: 'anon-meta-expiry',
        appMetadata: const {'provider': 'anonymous', 'providers': ['anonymous']},
        userMetadata: {'expires_at': customExpiry.toIso8601String()},
        aud: 'authenticated',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        isAnonymous: true,
      );
      final authService = AuthService(initialUser: user);
      expect(authService.guestExpirationTime, isNotNull);
      expect(
        authService.guestExpirationTime!.millisecondsSinceEpoch,
        closeTo(customExpiry.millisecondsSinceEpoch, 1000),
      );
    });

    test('signOut clears user and active guest session', () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.currentUser, isNotNull);

      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(authService.isAnonymous, isTrue);
      expect(authService.guestExpirationTime, isNull);
    });

    test('guestExpirationTime returns null when currentUser is null even with guestSessionStartTime', () {
      final authService = AuthService(guestSessionStartTime: DateTime.now());
      expect(authService.currentUser, isNull);
      expect(authService.guestExpirationTime, isNull);
      expect(authService.guestTimeRemaining, isNull);
      expect(authService.isGuestExpired, isFalse);
    });

    test('signInWithEmail and signUpWithEmail clear active guest session start time and TTL', () async {
      final authService = AuthService();
      await authService.signInAnonymously();
      expect(authService.currentUser, isNotNull);
      expect(authService.guestExpirationTime, isNotNull);

      // Signing in with email should clear guest TTL
      await authService.signInWithEmail(email: 'user@pulsefit.ai', password: 'password123');
      expect(authService.isAnonymous, isFalse);
      expect(authService.guestExpirationTime, isNull);

      // Signing up with email should also ensure guest TTL is cleared
      final authService2 = AuthService();
      await authService2.signInAnonymously();
      expect(authService2.guestExpirationTime, isNotNull);

      await authService2.signUpWithEmail(
        email: 'brandnew@pulsefit.ai',
        password: 'password123',
        displayName: 'Brand New',
      );
      expect(authService2.isAnonymous, isFalse);
      expect(authService2.guestExpirationTime, isNull);
    });
  });
}

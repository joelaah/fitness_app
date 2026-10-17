import 'package:fitness_app/features/auth/services/auth_service.dart';
import 'package:fitness_app/features/workout/services/ai_quota_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AiQuotaService Quota Enforcement & Rate Limiting (R1)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state: free and guest users start with 5 remaining queries', () async {
      final service = AiQuotaService();

      expect(await service.canMakeQuery(), isTrue);
      expect(await service.getRemainingQueries(), equals(5));
      expect(await service.getUsedQueries(), equals(0));
    });

    test('Enforcement: free/guest user is blocked after exactly 5 queries with accurate remaining count', () async {
      final service = AiQuotaService();

      // Query 1
      expect(await service.canMakeQuery(), isTrue);
      await service.consumeQuery();
      expect(await service.getRemainingQueries(), equals(4));
      expect(await service.getUsedQueries(), equals(1));

      // Query 2
      expect(await service.canMakeQuery(), isTrue);
      await service.consumeQuery();
      expect(await service.getRemainingQueries(), equals(3));
      expect(await service.getUsedQueries(), equals(2));

      // Query 3
      expect(await service.canMakeQuery(), isTrue);
      await service.consumeQuery();
      expect(await service.getRemainingQueries(), equals(2));
      expect(await service.getUsedQueries(), equals(3));

      // Query 4
      expect(await service.canMakeQuery(), isTrue);
      await service.consumeQuery();
      expect(await service.getRemainingQueries(), equals(1));
      expect(await service.getUsedQueries(), equals(4));

      // Query 5 (final allowed free request)
      expect(await service.canMakeQuery(), isTrue);
      await service.consumeQuery();
      expect(await service.getRemainingQueries(), equals(0));
      expect(await service.getUsedQueries(), equals(5));

      // Query 6 (blocked)
      expect(await service.canMakeQuery(), isFalse);
      expect(
        () async => service.consumeQuery(),
        throwsA(isA<AiQuotaExceededException>()),
      );
      expect(await service.getRemainingQueries(), equals(0));
      expect(await service.getUsedQueries(), equals(5));
    });

    test('Upgraded/authenticated accounts have unrestricted unlimited access', () async {
      final permanentUser = User(
        id: 'upgraded-user-001',
        appMetadata: const {'provider': 'email'},
        userMetadata: const {'display_name': 'Pro Coach'},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );

      final authService = AuthService(initialUser: permanentUser);
      final service = AiQuotaService(authService: authService);

      expect(service.isUpgradedUser(), isTrue);
      expect(await service.getRemainingQueries(), equals(-1)); // -1 denotes unlimited

      // Consuming 10 consecutive queries without being blocked
      for (var i = 0; i < 10; i++) {
        expect(await service.canMakeQuery(), isTrue);
        await service.consumeQuery();
      }

      expect(await service.canMakeQuery(), isTrue);
      expect(await service.getRemainingQueries(), equals(-1));
    });

    test('Explicit is_premium userMetadata grants unlimited access', () async {
      final premiumUser = User(
        id: 'premium-sub-user',
        appMetadata: const {},
        userMetadata: const {'is_premium': true},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );

      final service = AiQuotaService();
      expect(service.isUpgradedUser(user: premiumUser), isTrue);

      for (var i = 0; i < 8; i++) {
        expect(await service.canMakeQuery(user: premiumUser), isTrue);
        await service.consumeQuery(user: premiumUser);
      }

      expect(await service.canMakeQuery(user: premiumUser), isTrue);
      expect(await service.getRemainingQueries(user: premiumUser), equals(-1));
    });

    test('Anonymous guest users are identified as non-upgraded and capped at 5', () async {
      final anonUser = User(
        id: 'anon-guest-user',
        appMetadata: const {'provider': 'anonymous'},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: true,
      );

      final authService = AuthService(initialUser: anonUser);
      final service = AiQuotaService(authService: authService);

      expect(service.isUpgradedUser(), isFalse);

      for (var i = 0; i < 5; i++) {
        expect(await service.canMakeQuery(), isTrue);
        await service.consumeQuery();
      }

      expect(await service.canMakeQuery(), isFalse);
      expect(
        () async => service.consumeQuery(),
        throwsA(isA<AiQuotaExceededException>()),
      );
    });

    test('Quota automatically resets after 24 hours', () async {
      DateTime simulatedTime = DateTime.utc(2026, 10, 1, 10, 0, 0);
      final service = AiQuotaService(clock: () => simulatedTime);

      // Exhaust 5 queries at 10:00 AM
      for (var i = 0; i < 5; i++) {
        await service.consumeQuery();
      }
      expect(await service.canMakeQuery(), isFalse);
      expect(await service.getRemainingQueries(), equals(0));

      // Advance clock by 23 hours (same UTC day or under 24h, still blocked if same day or <24h)
      simulatedTime = simulatedTime.add(const Duration(hours: 12));
      // Cross to 22:00 (12 hours later, same day)
      expect(await service.canMakeQuery(), isFalse);

      // Advance clock past 24 hours (simulatedTime = 2026-10-02 10:05:00)
      simulatedTime = DateTime.utc(2026, 10, 1, 10, 0, 0).add(const Duration(hours: 24, minutes: 5));
      expect(await service.canMakeQuery(), isTrue);
      expect(await service.getRemainingQueries(), equals(5));
      expect(await service.getUsedQueries(), equals(0));
    });

    test('Quota automatically resets at 00:00 UTC midnight boundary', () async {
      // 23:45 UTC on Oct 1
      DateTime simulatedTime = DateTime.utc(2026, 10, 1, 23, 45, 0);
      final service = AiQuotaService(clock: () => simulatedTime);

      // Exhaust 5 queries
      for (var i = 0; i < 5; i++) {
        await service.consumeQuery();
      }
      expect(await service.canMakeQuery(), isFalse);
      expect(await service.getRemainingQueries(), equals(0));

      // Advance clock 20 minutes to 00:05 UTC on Oct 2
      simulatedTime = DateTime.utc(2026, 10, 2, 0, 5, 0);

      // Automatically reset because UTC day has transitioned
      expect(await service.canMakeQuery(), isTrue);
      expect(await service.getRemainingQueries(), equals(5));
      expect(await service.getUsedQueries(), equals(0));
    });

    test('Persists quota count and window across separate service instances via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service1 = AiQuotaService(prefs: prefs);
      await service1.consumeQuery();
      await service1.consumeQuery();
      expect(await service1.getRemainingQueries(), equals(3));

      // Second instance sharing the same preferences
      final service2 = AiQuotaService(prefs: prefs);
      expect(await service2.getRemainingQueries(), equals(3));
      expect(await service2.getUsedQueries(), equals(2));

      await service2.consumeQuery();
      expect(await service2.getRemainingQueries(), equals(2));
      expect(await service1.getRemainingQueries(), equals(2));
    });

    test('Manual resetQuota clears used count and refreshes full allowance', () async {
      final service = AiQuotaService();
      for (var i = 0; i < 5; i++) {
        await service.consumeQuery();
      }
      expect(await service.canMakeQuery(), isFalse);

      await service.resetQuota();
      expect(await service.canMakeQuery(), isTrue);
      expect(await service.getRemainingQueries(), equals(5));
      expect(await service.getUsedQueries(), equals(0));
    });
  });
}

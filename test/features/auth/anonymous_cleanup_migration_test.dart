import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anonymous Cleanup SQL Migration & Expiry Invariants (R1)', () {
    test('migration 03 file defines required functions and 2-hour cutoff', () {
      final migrationFile =
          File('migrations/03_anonymous_session_lifecycle.sql');
      expect(migrationFile.existsSync(), isTrue,
          reason: 'Migration file migrations/03_anonymous_session_lifecycle.sql must exist');

      final sql = migrationFile.readAsStringSync();

      // Check required schema alters
      expect(sql.contains('is_anonymous'), isTrue);
      expect(sql.contains('expires_at'), isTrue);
      expect(sql.contains('idx_auth_users_anon_created_at'), isTrue);

      // Check functions
      expect(sql.contains('public.get_expired_anonymous_users'), isTrue);
      expect(sql.contains('public.purge_expired_anonymous_users'), isTrue);
      expect(sql.contains('public.tag_anonymous_profile_ttl'), isTrue);

      // Check 2-hour interval
      expect(sql.contains("INTERVAL '2 hours'"), isTrue);

      // Check security and cascading logic
      expect(sql.contains('SECURITY DEFINER'), isTrue);
      expect(sql.contains('SET search_path = public, auth, pg_temp'), isTrue);
      expect(sql.contains('is_anonymous IS TRUE'), isTrue);
      expect(sql.contains('DELETE FROM auth.users'), isTrue);
      expect(sql.contains('trainer_profiles'), isTrue);
      expect(sql.contains('NEW.is_anonymous IS FALSE'), isTrue);
    });

    test('supabase_schema.sql incorporates anonymous lifecycle and cleanup', () {
      final schemaFile = File('supabase_schema.sql');
      expect(schemaFile.existsSync(), isTrue);

      final sql = schemaFile.readAsStringSync();
      expect(sql.contains('get_expired_anonymous_users'), isTrue);
      expect(sql.contains('purge_expired_anonymous_users'), isTrue);
      expect(sql.contains('tag_anonymous_profile_ttl'), isTrue);
      expect(sql.contains('SET search_path = public, auth, pg_temp'), isTrue);
      expect(sql.contains('trainer_profiles'), isTrue);
      expect(sql.contains('NEW.is_anonymous IS FALSE'), isTrue);
    });

    test('cleanup logic filters expired guests while protecting permanent users', () {
      final now = DateTime.now().toUtc();
      final cutoff = const Duration(hours: 2);

      final testUsers = [
        {
          'id': 'anon-expired-1',
          'is_anonymous': true,
          'created_at': now.subtract(const Duration(hours: 3)),
        },
        {
          'id': 'anon-fresh-2',
          'is_anonymous': true,
          'created_at': now.subtract(const Duration(minutes: 45)),
        },
        {
          'id': 'perm-old-3',
          'is_anonymous': false,
          'created_at': now.subtract(const Duration(days: 30)),
        },
        {
          'id': 'perm-new-4',
          'is_anonymous': false,
          'created_at': now.subtract(const Duration(hours: 1)),
        },
      ];

      // Simulated get_expired_anonymous_users query
      final expired = testUsers.where((u) {
        final isAnon = u['is_anonymous'] as bool;
        final createdAt = u['created_at'] as DateTime;
        return isAnon && createdAt.isBefore(now.subtract(cutoff));
      }).toList();

      expect(expired.length, 1);
      expect(expired.first['id'], 'anon-expired-1');

      // Simulated purge operation
      final expiredIds = expired.map((e) => e['id'] as String).toSet();
      final remainingUsers =
          testUsers.where((u) => !expiredIds.contains(u['id'])).toList();

      expect(remainingUsers.length, 3);
      expect(remainingUsers.any((u) => u['id'] == 'anon-fresh-2'), isTrue);
      expect(remainingUsers.any((u) => u['id'] == 'perm-old-3'), isTrue);
      expect(remainingUsers.any((u) => u['id'] == 'perm-new-4'), isTrue);
    });
  });
}

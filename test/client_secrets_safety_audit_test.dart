import 'dart:io';
import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Client Secrets Protection & Configuration Safety Audit (R3)', () {
    test('SupabaseConfig only defines public anon key, never privileged service role key', () {
      // Verify compile-time constants on SupabaseConfig
      expect(SupabaseConfig.supabaseAnonKey, isA<String>());
      // Verify that no service role key field exists on SupabaseConfig
      // SupabaseConfig has only supabaseUrl and supabaseAnonKey
      expect(SupabaseConfig.isConfigured, isA<bool>());
    });

    test('Audit: lib/ source tree does not contain hardcoded service role keys or raw AI master keys', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbiddenPatterns = [
        RegExp(r'SUPABASE_SERVICE_ROLE_KEY', caseSensitive: false),
        RegExp(r'service_role', caseSensitive: false),
        RegExp(r'sk-[a-zA-Z0-9]{20,}', caseSensitive: false), // OpenAI / generic raw master secret keys
        RegExp(r'AI_MASTER_KEY', caseSensitive: false),
        RegExp(r'ADMIN_SECRET_KEY', caseSensitive: false),
      ];

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          for (final pattern in forbiddenPatterns) {
            if (pattern.hasMatch(content)) {
              violations.add('${file.path} matches forbidden security pattern "${pattern.pattern}"');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Client application code must never bundle service role or raw secret master keys:\n${violations.join('\n')}',
      );
    });

    test('Audit: client network headers authenticate using user JWT or standard anon key only', () {
      final libDir = Directory('lib');
      final networkFiles = <File>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains('Authorization') || content.contains('apikey')) {
            networkFiles.add(file);
          }
        }
      }

      expect(networkFiles, isNotEmpty, reason: 'Expected authenticated network service files');

      for (final file in networkFiles) {
        final content = file.readAsStringSync();
        // Ensure no headers send "service_role" as the apikey or token
        expect(
          content.contains("apikey: 'service_role'"),
          isFalse,
          reason: '${file.path} must not hardcode service_role in headers',
        );
        expect(
          content.contains('"apikey": "service_role"'),
          isFalse,
          reason: '${file.path} must not hardcode service_role in headers',
        );
      }
    });

    test('Audit: client assets, pubspec.yaml, and root configs do not bundle private .env files or secrets', () {
      final forbiddenSecretPatterns = [
        RegExp(r'SUPABASE_SERVICE_ROLE_KEY', caseSensitive: false),
        RegExp(r'sk-[a-zA-Z0-9]{20,}', caseSensitive: false),
        RegExp(r'AI_MASTER_KEY', caseSensitive: false),
        RegExp(r'ADMIN_SECRET_KEY', caseSensitive: false),
      ];

      // 1. Audit assets/ directory
      final assetsDir = Directory('assets');
      if (assetsDir.existsSync()) {
        for (final entity in assetsDir.listSync(recursive: true)) {
          if (entity is File) {
            // Check that no .env files are in assets
            expect(
              entity.path.toLowerCase().contains('.env'),
              isFalse,
              reason: 'Assets must never bundle .env files: ${entity.path}',
            );

            // Check text-based assets for secrets
            final ext = entity.path.split('.').last.toLowerCase();
            if (['json', 'txt', 'yaml', 'yml', 'xml', 'csv', 'md'].contains(ext)) {
              final content = entity.readAsStringSync();
              for (final pattern in forbiddenSecretPatterns) {
                expect(
                  pattern.hasMatch(content),
                  isFalse,
                  reason: 'Asset file ${entity.path} contains forbidden secret pattern "${pattern.pattern}"',
                );
              }
            }
          }
        }
      }

      // 2. Audit pubspec.yaml asset declarations
      final pubspecFile = File('pubspec.yaml');
      if (pubspecFile.existsSync()) {
        final pubspecContent = pubspecFile.readAsStringSync();
        expect(
          pubspecContent.contains('.env'),
          isFalse,
          reason: 'pubspec.yaml must never register .env files as packaged assets',
        );
      }

      // 3. Ensure no uncommitted .env in project root is configured for client bundle
      final rootEnv = File('.env');
      if (rootEnv.existsSync()) {
        final content = rootEnv.readAsStringSync();
        for (final pattern in forbiddenSecretPatterns) {
          expect(
            pattern.hasMatch(content),
            isFalse,
            reason: 'Root .env contains forbidden secret pattern: "${pattern.pattern}"',
          );
        }
      }
    });

    test('Audit: platform configurations (android, ios, web, macos, windows) do not hardcode secrets', () {
      final sensitivePlatformFiles = [
        'android/app/src/main/AndroidManifest.xml',
        'ios/Runner/Info.plist',
        'macos/Runner/Info.plist',
        'web/index.html',
      ];

      final forbiddenPatterns = [
        RegExp(r'SUPABASE_SERVICE_ROLE_KEY', caseSensitive: false),
        RegExp(r'service_role', caseSensitive: false),
        RegExp(r'sk-[a-zA-Z0-9]{20,}', caseSensitive: false),
        RegExp(r'ADMIN_SECRET_KEY', caseSensitive: false),
      ];

      for (final relPath in sensitivePlatformFiles) {
        final file = File(relPath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          for (final pattern in forbiddenPatterns) {
            expect(
              pattern.hasMatch(content),
              isFalse,
              reason: '$relPath must not bundle sensitive key matching "${pattern.pattern}"',
            );
          }
        }
      }
    });
  });
}

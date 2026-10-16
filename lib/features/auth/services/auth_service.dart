import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  /// Current user in Supabase
  User? get currentUser => _supabase?.auth.currentUser;

  /// Current user ID
  String? get currentUserId => currentUser?.id;

  /// Whether current session is an anonymous guest
  bool get isAnonymous {
    final user = currentUser;
    if (user == null) return true;
    return user.isAnonymous;
  }

  /// Upgrades an anonymous user to permanent email/password account
  /// Preserves the user ID and linked workout history.
  Future<UserResponse> upgradeAnonymousUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint('AuthService: Mock auth upgrade for $email');
      return UserResponse.fromJson(<String, dynamic>{
        'id': 'mock-upgraded-user',
        'email': email,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{'display_name': displayName},
        'aud': 'authenticated',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    final response = await client.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
        data: <String, dynamic>{'display_name': displayName},
      ),
    );

    // Sync display name to public.profiles
    if (response.user != null) {
      try {
        await client.from('profiles').upsert(<String, dynamic>{
          'id': response.user!.id,
          'display_name': displayName,
        });
      } on Exception catch (e) {
        debugPrint('AuthService profile upsert notice: $e');
      }
    }

    return response;
  }

  /// Signs in an existing user with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint('AuthService: Mock sign-in for $email');
      return AuthResponse();
    }

    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs up a new permanent account from scratch
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _supabase;
    if (client == null) {
      return AuthResponse();
    }

    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'display_name': displayName},
    );

    if (response.user != null) {
      try {
        await client.from('profiles').upsert(<String, dynamic>{
          'id': response.user!.id,
          'display_name': displayName,
        });
      } on Exception catch (e) {
        debugPrint('AuthService profile upsert notice: $e');
      }
    }

    return response;
  }
}

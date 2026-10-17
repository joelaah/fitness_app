import 'package:fitness_app/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({
    SupabaseClient? client,
    User? initialUser,
    DateTime? guestSessionStartTime,
    Stream<AuthState>? authStateStream,
  })  : _client = client,
        _mockUser = initialUser,
        _mockAuthStateStream = authStateStream,
        _guestSessionStartTime = guestSessionStartTime ??
            (initialUser != null
                ? DateTime.tryParse(initialUser.createdAt)
                : null);

  final SupabaseClient? _client;
  final Stream<AuthState>? _mockAuthStateStream;
  User? _mockUser;
  DateTime? _guestSessionStartTime;
  bool _upgradeRequested = false;

  /// Web redirect URL for OAuth authentication callback loops
  static const String _webRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Reactive stream of Supabase auth state changes
  Stream<AuthState>? get onAuthStateChange =>
      _mockAuthStateStream ?? _supabase?.auth.onAuthStateChange;

  /// 2-hour TTL window for unlinked anonymous guest data
  static const Duration guestDataTtl = Duration(hours: 2);

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (SupabaseConfig.isInitialized) {
      return Supabase.instance.client;
    }
    return null;
  }

  /// Current user in Supabase or active test session
  User? get currentUser => _supabase?.auth.currentUser ?? _mockUser;

  /// Current user ID
  String? get currentUserId => currentUser?.id;

  /// Whether current session is an anonymous guest
  bool get isAnonymous {
    if (_upgradeRequested) return false;
    final user = currentUser;
    if (user == null) return true;
    return user.isAnonymous;
  }

  /// The point in time when this anonymous guest session data will auto-expire.
  /// Returns null for permanent verified accounts.
  DateTime? get guestExpirationTime {
    if (!isAnonymous || currentUser == null) return null;
    final user = currentUser;
    if (user != null) {
      if (user.userMetadata != null &&
          user.userMetadata!['expires_at'] != null) {
        final parsedExpiresAt =
            DateTime.tryParse(user.userMetadata!['expires_at'].toString());
        if (parsedExpiresAt != null) return parsedExpiresAt;
      }
      final parsedCreatedAt = DateTime.tryParse(user.createdAt);
      if (parsedCreatedAt != null) {
        return parsedCreatedAt.add(guestDataTtl);
      }
    }
    if (_guestSessionStartTime != null) {
      return _guestSessionStartTime!.add(guestDataTtl);
    }
    return null;
  }

  /// Remaining duration before guest session data expires.
  /// Returns Duration.zero if the 2-hour window has elapsed.
  Duration? get guestTimeRemaining {
    final expiry = guestExpirationTime;
    if (expiry == null) return null;
    final remaining = expiry.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether the guest session has reached or exceeded the 2-hour TTL window.
  bool get isGuestExpired {
    if (!isAnonymous) return false;
    final remaining = guestTimeRemaining;
    if (remaining == null) return false;
    return remaining == Duration.zero;
  }

  /// Initializes an anonymous guest session using Supabase anon credentials.
  /// Automatically tags user metadata with the 2-hour TTL window.
  Future<AuthResponse> signInAnonymously({Map<String, dynamic>? data}) async {
    _upgradeRequested = false;
    final client = _supabase;
    final nowUtc = DateTime.now().toUtc();
    final ttlData = <String, dynamic>{
      'ttl_hours': 2,
      'expires_at': nowUtc.add(guestDataTtl).toIso8601String(),
      ...?data,
    };

    if (client == null) {
      debugPrint('AuthService: Mock anonymous sign-in');
      final anonId = 'mock-anon-user-${DateTime.now().millisecondsSinceEpoch}';
      final nowStr = nowUtc.toIso8601String();
      final anonUser = User(
        id: anonId,
        appMetadata: const {
          'provider': 'anonymous',
          'providers': ['anonymous'],
        },
        userMetadata: ttlData,
        aud: 'authenticated',
        createdAt: nowStr,
        isAnonymous: true,
      );
      _mockUser = anonUser;
      _guestSessionStartTime = nowUtc;

      return AuthResponse(
        session: Session(
          accessToken: 'mock-anon-token',
          tokenType: 'bearer',
          user: anonUser,
        ),
        user: anonUser,
      );
    }

    final response = await client.auth.signInAnonymously(data: ttlData);
    if (response.user != null) {
      _guestSessionStartTime =
          DateTime.tryParse(response.user!.createdAt) ?? DateTime.now().toUtc();
    }
    return response;
  }

  /// Upgrades or links an anonymous session with an OAuth provider (Google, Apple, etc.).
  /// Strictly preserves the user's existing UUID, workout logs, routines, and profile.
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
  }) async {
    final client = _supabase;
    final effectiveRedirect = redirectTo ?? (kIsWeb ? _webRedirectUrl : null);

    if (client == null) {
      debugPrint('AuthService: Mock OAuth upgrade for ${provider.name}');
      final preservedId = currentUserId ?? 'mock-oauth-user';
      final existingCreatedAt =
          currentUser?.createdAt ?? DateTime.now().toUtc().toIso8601String();
      _mockUser = User(
        id: preservedId,
        appMetadata: {
          'provider': provider.name,
          'providers': [provider.name],
        },
        userMetadata: currentUser?.userMetadata ?? {},
        aud: 'authenticated',
        createdAt: existingCreatedAt,
        isAnonymous: false,
      );
      _guestSessionStartTime = null;
      _upgradeRequested = true;
      return true;
    }

    // If currently an active anonymous session, linking identity preserves UUID
    if (currentUser != null && isAnonymous) {
      try {
        final linked = await client.auth.linkIdentity(
          provider,
          redirectTo: effectiveRedirect,
        );
        if (linked) {
          _guestSessionStartTime = null;
          _upgradeRequested = true;
          final userId = client.auth.currentUser?.id;
          if (userId != null) {
            try {
              await client.from('profiles').upsert(<String, dynamic>{
                'id': userId,
                'is_anonymous': false,
                'expires_at': null,
              });
            } on Exception catch (e) {
              debugPrint('AuthService profile link sync notice: $e');
            }
          }
        }
        return linked;
      } on Exception catch (e) {
        debugPrint(
          'AuthService linkIdentity notice: $e; falling back to signInWithOAuth',
        );
      }
    }

    final success = await client.auth.signInWithOAuth(
      provider,
      redirectTo: effectiveRedirect,
    );
    if (success) {
      _guestSessionStartTime = null;
      _upgradeRequested = true;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        try {
          await client.from('profiles').upsert(<String, dynamic>{
            'id': userId,
            'is_anonymous': false,
            'expires_at': null,
          });
        } on Exception catch (e) {
          debugPrint('AuthService profile OAuth sync notice: $e');
        }
      }
    }
    return success;
  }

  /// Convenience method to upgrade guest session to Google OAuth
  Future<bool> linkWithGoogle({String? redirectTo}) =>
      signInWithOAuth(OAuthProvider.google, redirectTo: redirectTo);

  /// Convenience method to upgrade guest session to Apple OAuth
  Future<bool> linkWithApple({String? redirectTo}) =>
      signInWithOAuth(OAuthProvider.apple, redirectTo: redirectTo);

  /// Convenience alias for OAuth linking
  Future<bool> linkWithOAuth(OAuthProvider provider, {String? redirectTo}) =>
      signInWithOAuth(provider, redirectTo: redirectTo);

  /// Upgrades an anonymous user to permanent email/password account.
  /// Strictly preserves the user ID and linked workout history.
  Future<UserResponse> upgradeAnonymousUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint('AuthService: Mock auth upgrade for $email');
      final preservedId = currentUserId ?? 'mock-upgraded-user';
      final existingCreatedAt =
          currentUser?.createdAt ?? DateTime.now().toUtc().toIso8601String();
      final upgradedUser = User(
        id: preservedId,
        email: email,
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: <String, dynamic>{'display_name': displayName},
        aud: 'authenticated',
        createdAt: existingCreatedAt,
        isAnonymous: false,
      );
      _mockUser = upgradedUser;
      _guestSessionStartTime = null;
      _upgradeRequested = true;

      return UserResponse.fromJson(<String, dynamic>{
        'id': preservedId,
        'email': email,
        'app_metadata': const {'provider': 'email', 'providers': ['email']},
        'user_metadata': <String, dynamic>{'display_name': displayName},
        'aud': 'authenticated',
        'created_at': existingCreatedAt,
        'is_anonymous': false,
      });
    }

    if (client.auth.currentUser == null) {
      // Fallback if no anonymous session exists: create new permanent account
      final signUpResponse = await signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      _upgradeRequested = true;
      return UserResponse.fromJson(<String, dynamic>{
        if (signUpResponse.user != null) ...<String, dynamic>{
          'id': signUpResponse.user!.id,
          'email': signUpResponse.user!.email,
          'app_metadata': signUpResponse.user!.appMetadata,
          'user_metadata': signUpResponse.user!.userMetadata,
          'aud': signUpResponse.user!.aud,
          'created_at': signUpResponse.user!.createdAt,
          'is_anonymous': false,
        },
      });
    }

    final response = await client.auth.updateUser(
      UserAttributes(
        email: email,
        password: password,
        data: <String, dynamic>{'display_name': displayName},
      ),
    );

    // Sync display name and clear anonymous TTL on public.profiles
    if (response.user != null) {
      _guestSessionStartTime = null;
      _upgradeRequested = true;
      try {
        await client.auth.refreshSession();
      } catch (e) {
        debugPrint('AuthService refreshSession notice: $e');
      }
      try {
        await client.from('profiles').upsert(<String, dynamic>{
          'id': response.user!.id,
          'display_name': displayName,
          'is_anonymous': false,
          'expires_at': null,
        });
      } on Exception catch (e) {
        debugPrint('AuthService profile upsert notice: $e');
      }
    }

    return response;
  }

  /// Alias for upgradeAnonymousUser
  Future<UserResponse> linkWithEmail({
    required String email,
    required String password,
    String displayName = 'Coach',
  }) =>
      upgradeAnonymousUser(
        email: email,
        password: password,
        displayName: displayName,
      );

  /// Signs in an existing user with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _supabase;
    if (client == null) {
      debugPrint('AuthService: Mock sign-in for $email');
      final user = User(
        id: 'mock-user-id',
        email: email,
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      _mockUser = user;
      _guestSessionStartTime = null;
      return AuthResponse(
        session: Session(
          accessToken: 'mock-token',
          tokenType: 'bearer',
          user: user,
        ),
        user: user,
      );
    }

    _guestSessionStartTime = null;
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
      final user = User(
        id: 'mock-new-user-id',
        email: email,
        appMetadata: const {'provider': 'email', 'providers': ['email']},
        userMetadata: {'display_name': displayName},
        aud: 'authenticated',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        isAnonymous: false,
      );
      _mockUser = user;
      _guestSessionStartTime = null;
      return AuthResponse(
        session: Session(
          accessToken: 'mock-new-token',
          tokenType: 'bearer',
          user: user,
        ),
        user: user,
      );
    }

    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'display_name': displayName},
    );

    if (response.user != null) {
      _guestSessionStartTime = null;
      try {
        await client.from('profiles').upsert(<String, dynamic>{
          'id': response.user!.id,
          'display_name': displayName,
          'is_anonymous': false,
          'expires_at': null,
        });
      } on Exception catch (e) {
        debugPrint('AuthService profile upsert notice: $e');
      }
    }

    return response;
  }

  /// Signs out the current user session
  Future<void> signOut() async {
    final client = _supabase;
    _mockUser = null;
    _guestSessionStartTime = null;
    _upgradeRequested = false;
    if (client != null) {
      await client.auth.signOut();
    }
  }
}

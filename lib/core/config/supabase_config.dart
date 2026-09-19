/// Configuration constants for Supabase backend.
/// Values can be supplied via --dart-define or configured directly.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ogbqkmujgmukbxxpjdsa.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_nSGbvUYVau8Xmwm8A0Z7Zw_N01ydmzk',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Tracks whether Supabase.initialize has completed successfully
  static bool isInitialized = false;
}

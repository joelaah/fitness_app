/// Configuration constants for Supabase backend.
/// Values can be supplied via --dart-define or configured directly.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ogbqkmujgmukbxxpjdsa.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9nYnFrbXVqZ211a2J4eHBqZHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk3Mzg2OTgsImV4cCI6MjEwNTMxNDY5OH0.Kw3pXjB60oau3ZIEfOC5leg1iYbmzgOEFkv42CHLzK8',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Tracks whether Supabase.initialize has completed successfully
  static bool isInitialized = false;
}

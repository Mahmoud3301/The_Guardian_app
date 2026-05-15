// lib/core/supabase_config.dart
// Centralised Supabase credentials — matches the Python desktop app.

class SupabaseConfig {
  SupabaseConfig._();

  static const String url =
      'https://ldtqguseonfhkjfxuocl.supabase.co';

  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxkdHFndXNlb25maGtqZnh1b2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0MDgwNzMsImV4cCI6MjA5MDk4NDA3M30.'
      'qSsDcm1rchiy3EWR9i3om3vZpII6F_iteGwaxr6XGNY';

  /// Storage bucket that holds both face photos and embeddings.
  static const String bucketName = 'DataBase';

  /// Prefix inside the bucket for face photos.
  static const String photosPath = 'faces';

  /// Prefix inside the bucket for face-encoding JSON files.
  static const String embeddingsPath = 'embeddings';
}

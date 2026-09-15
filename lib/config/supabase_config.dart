/// Supabase project used by Recipe Keeper.
///
/// The anon key is a public, publishable key (row-level security and edge
/// function policies protect the backend); it is safe to ship in the app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://kqhufomrgvpagbziwwok.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtxaHVmb21yZ3ZwYWdieml3d29rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4Njc3NjAsImV4cCI6MjA4MDQ0Mzc2MH0.HI2iJoM1tsrJewbEdKIUEpQ5CkLFOwv--aS0L8vZ0j4';
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class SupabaseService {
  static bool _isInitialized = false;
  static final StreamController<bool> _initController =
      StreamController<bool>.broadcast();
  
  static bool get isInitialized => _isInitialized;
  static Stream<bool> get initStream => _initController.stream;
  
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        'Supabase is not initialized. Please ensure Supabase credentials are configured.',
      );
    }
    return Supabase.instance.client;
  }
  
  static String? _url;
  static String? _anonKey;
  
  static String? get url => _url;
  static String? get anonKey => _anonKey;
  
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    _url = url;
    _anonKey = anonKey;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        // No accounts: the app only ever uses the anon key.
        autoRefreshToken: false,
      ),
    );
    _isInitialized = true;
    _initController.add(true);
  }
  
  /// Tears the client down (tests). The app never calls this.
  static Future<void> dispose() async {
    if (!_isInitialized) return;
    _isInitialized = false;
    await Supabase.instance.dispose();
  }
}

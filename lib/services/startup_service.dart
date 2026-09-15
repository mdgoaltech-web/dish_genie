import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

/// One-time app start-up work: local storage and the Supabase client.
class StartupService {
  StartupService._();

  static bool _isInitialized = false;
  static Future<void>? _inFlight;

  static bool get isInitialized => _isInitialized;

  static Future<void> start() {
    if (_isInitialized) return Future.value();
    return _inFlight ??= _run();
  }

  static Future<void> _run() async {
    try {
      await StorageService.initialize();
      await SupabaseService.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] initialization failed: $e');
    } finally {
      _inFlight = null;
    }
  }
}

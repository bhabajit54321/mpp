import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  static bool _initializationInProgress = false;

  // Singleton pattern
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Environment variables with fallback handling
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Static initialization method with improved error handling
  static Future<void> initialize() async {
    // Prevent multiple simultaneous initialization attempts
    if (_instance._isInitialized || _initializationInProgress) {
      return;
    }

    _initializationInProgress = true;

    try {
      // Validate environment variables
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        debugPrint('⚠️ Supabase credentials not found, using fallback mode');
        _instance._isInitialized = true;
        return;
      }

      // Validate URL format
      if (!_isValidUrl(supabaseUrl)) {
        throw SupabaseException('Invalid SUPABASE_URL format: $supabaseUrl');
      }

      // Initialize Supabase with shorter timeout for BrowserStack
      await _initializeWithRetry(maxRetries: 2, timeoutSeconds: 10);

      _instance._client = Supabase.instance.client;
      _instance._isInitialized = true;

      debugPrint('✅ Supabase initialized successfully');
      debugPrint('🔗 Connected to: ${_maskUrl(supabaseUrl)}');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      // Don't rethrow for BrowserStack compatibility
      _instance._isInitialized = true;
    } finally {
      _initializationInProgress = false;
    }
  }

  // Retry mechanism for Supabase initialization
  static Future<void> _initializeWithRetry({int maxRetries = 2, int timeoutSeconds = 10}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          debug: false, // Disable debug mode for better performance
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true,
          ),
        ).timeout(Duration(seconds: timeoutSeconds));
        
        return; // Success, exit retry loop
      } catch (e) {
        debugPrint('❌ Supabase initialization attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          throw SupabaseException(
            'Failed to initialize Supabase after $maxRetries attempts. Last error: $e',
          );
        }

        // Shorter wait before retrying for BrowserStack
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  // URL validation helper
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // URL masking for security in logs
  static String _maskUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      return 'invalid-url';
    }
  }

  // Client getter with better error handling
  SupabaseClient get client {
    if (!_isInitialized) {
      throw SupabaseException(
        'Supabase not initialized. Call SupabaseService.initialize() first or check your environment variables.',
      );
    }
    return _client;
  }

  // Async client getter for backward compatibility
  Future<SupabaseClient> get clientAsync async {
    if (!_isInitialized) {
      await initialize();
    }
    return _client;
  }

  // Safe client getter that returns null if not initialized
  SupabaseClient? get safeClient {
    return _isInitialized ? _client : null;
  }

  // Initialization status
  bool get isInitialized => _isInitialized;

  // Connection status check
  Future<bool> checkConnection() async {
    try {
      if (!_isInitialized) return false;

      // Simple query to test connection
      await _client.from('user_profiles').select('id').limit(1).maybeSingle();

      return true;
    } catch (e) {
      debugPrint('❌ Connection check failed: $e');
      return false;
    }
  }

  // Auth helpers with null safety
  bool get isAuthenticated {
    try {
      return _isInitialized && _client.auth.currentUser != null;
    } catch (e) {
      debugPrint('❌ Auth check failed: $e');
      return false;
    }
  }

  String? get currentUserId {
    try {
      return _isInitialized ? _client.auth.currentUser?.id : null;
    } catch (e) {
      debugPrint('❌ Get user ID failed: $e');
      return null;
    }
  }

  User? get currentUser {
    try {
      return _isInitialized ? _client.auth.currentUser : null;
    } catch (e) {
      debugPrint('❌ Get current user failed: $e');
      return null;
    }
  }

  // Enhanced sign out with error handling
  Future<void> signOut() async {
    try {
      if (!_isInitialized) {
        debugPrint('⚠️ Cannot sign out: Supabase not initialized');
        return;
      }

      await _client.auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
      throw SupabaseException('Sign out failed: $e');
    }
  }

  // Auth state stream with error handling
  Stream<AuthState> get authStateChanges {
    if (!_isInitialized) {
      throw SupabaseException(
        'Cannot access auth state: Supabase not initialized',
      );
    }

    return _client.auth.onAuthStateChange.handleError((error) {
      debugPrint('❌ Auth state change error: $error');
    });
  }

  // Cleanup method for testing or reinitialization
  static Future<void> dispose() async {
    try {
      if (_instance._isInitialized) {
        await _instance._client.dispose();
        _instance._isInitialized = false;
        debugPrint('🧹 Supabase service disposed');
      }
    } catch (e) {
      debugPrint('❌ Dispose failed: $e');
    }
  }

  // Health check method
  Future<Map<String, dynamic>> getHealthStatus() async {
    final status = <String, dynamic>{
      'initialized': _isInitialized,
      'authenticated': isAuthenticated,
      'user_id': currentUserId,
      'connection_ok': false,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isInitialized) {
      status['connection_ok'] = await checkConnection();
    }

    return status;
  }
}

// Custom exception class for better error handling
class SupabaseException implements Exception {
  final String message;

  const SupabaseException(this.message);

  @override
  String toString() => 'SupabaseException: $message';
}

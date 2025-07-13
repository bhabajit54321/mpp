import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // Store the loaded values
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;

  // Static initialization method with improved error handling
  static Future<void> initialize() async {
    // Prevent multiple simultaneous initialization attempts
    if (_instance._isInitialized || _initializationInProgress) {
      debugPrint('⚠️ Supabase already initialized or in progress');
      return;
    }

    _initializationInProgress = true;

    try {
      // Load environment variables
      await _loadEnvironmentVariables();

      // Validate environment variables
      if (_supabaseUrl == null || _supabaseUrl!.isEmpty || 
          _supabaseAnonKey == null || _supabaseAnonKey!.isEmpty) {
        throw SupabaseException(
          'Supabase credentials not found. Please check your .env file or environment variables.',
        );
      }

      // Validate URL format
      if (!_isValidUrl(_supabaseUrl!)) {
        throw SupabaseException('Invalid SUPABASE_URL format: $_supabaseUrl');
      }

      debugPrint('🔧 Initializing Supabase...');
      debugPrint('🔧 URL: ${_maskUrl(_supabaseUrl!)}');
      debugPrint('🔧 Key length: ${_supabaseAnonKey!.length}');

      // Initialize Supabase with retry mechanism
      await _initializeWithRetry();

      _instance._client = Supabase.instance.client;
      _instance._isInitialized = true;

      debugPrint('✅ Supabase initialized successfully');
      debugPrint('🔗 Connected to: ${_maskUrl(_supabaseUrl!)}');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }

  // Load environment variables from multiple sources
  static Future<void> _loadEnvironmentVariables() async {
    // Method 1: Try compile-time constants first (for --dart-define)
    const compileTimeUrl = String.fromEnvironment('SUPABASE_URL');
    const compileTimeKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    
    if (compileTimeUrl.isNotEmpty && compileTimeKey.isNotEmpty) {
      debugPrint('✅ Using compile-time environment variables');
      _supabaseUrl = compileTimeUrl;
      _supabaseAnonKey = compileTimeKey;
      return;
    }

    // Method 2: Try loading from .env file
    try {
      debugPrint('📄 Loading .env file...');
      await dotenv.load(fileName: '.env');
      
      _supabaseUrl = dotenv.env['SUPABASE_URL'];
      _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (_supabaseUrl != null && _supabaseAnonKey != null) {
        debugPrint('✅ Loaded credentials from .env file');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Could not load .env file: $e');
    }

    // Method 3: For Codemagic, check Platform environment
    try {
      // This works in Codemagic when variables are set in UI
      _supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
      _supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
      
      if (_supabaseUrl!.isEmpty || _supabaseAnonKey!.isEmpty) {
        throw Exception('Environment variables are empty');
      }
      
      debugPrint('✅ Using Codemagic environment variables');
    } catch (e) {
      debugPrint('❌ No environment variables found');
      _supabaseUrl = null;
      _supabaseAnonKey = null;
    }
  }

  // Retry mechanism for Supabase initialization
  static Future<void> _initializeWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Supabase.initialize(
          url: _supabaseUrl!,
          anonKey: _supabaseAnonKey!,
          debug: kDebugMode,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true,
          ),
        );
        return; // Success, exit retry loop
      } catch (e) {
        debugPrint('❌ Supabase initialization attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          throw SupabaseException(
            'Failed to initialize Supabase after $maxRetries attempts. Last error: $e',
          );
        }

        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
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
        'Supabase not initialized. Call SupabaseService.initialize() first.',
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
        _supabaseUrl = null;
        _supabaseAnonKey = null;
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
      'has_url': _supabaseUrl != null,
      'has_key': _supabaseAnonKey != null,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isInitialized) {
      status['connection_ok'] = await checkConnection();
    }

    return status;
  }

  // Debug method to check credentials
  static void debugCredentials() {
    debugPrint('🔍 Supabase Credentials Check:');
    debugPrint('   URL present: ${_supabaseUrl != null && _supabaseUrl!.isNotEmpty}');
    debugPrint('   Key present: ${_supabaseAnonKey != null && _supabaseAnonKey!.isNotEmpty}');
    if (_supabaseUrl != null) {
      debugPrint('   URL: ${_maskUrl(_supabaseUrl!)}');
    }
    if (_supabaseAnonKey != null) {
      debugPrint('   Key length: ${_supabaseAnonKey!.length}');
    }
  }
}

// Custom exception class for better error handling
class SupabaseException implements Exception {
  final String message;

  const SupabaseException(this.message);

  @override
  String toString() => 'SupabaseException: $message';
}
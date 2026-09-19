import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  
  static bool _isEmulatorMode = false;
  static bool get isEmulatorMode => _isEmulatorMode;

  /// Initializes the Firebase emulator connections securely based on environment flags.
  /// Enforces a strict fail-safe: Emulators CANNOT be activated in Release mode, regardless of flags.
  static Future<void> initialize({bool? forceEmulatorForTest}) async {
    // 1. Strict Environment Guard: Never allow emulators in release/production builds.
    if (kReleaseMode) {
      _isEmulatorMode = false;
      return;
    }

    // 2. Evaluate explicit compile-time flag (Defaults to FALSE for safety)
    // Developers must explicitly pass --dart-define=USE_EMULATORS=true to activate.
    // For unit testing, we allow an explicit override.
    final bool useEmulator = forceEmulatorForTest ?? const bool.fromEnvironment('USE_EMULATORS', defaultValue: false);
    
    _isEmulatorMode = useEmulator;
    
    if (useEmulator) {
      try {
        final host = _getEmulatorHost();
        
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
        
        debugPrint('✅ Connected to Firebase Emulators at $host');
      } catch (e) {
        debugPrint('🚨 CRITICAL ERROR: Failed to connect to Firebase Emulators: $e');
        // Stop execution if we expected to use emulators but failed.
        // We do NOT want to silently fail over to production.
        throw Exception('Emulator connection failed. Halting application for safety.');
      }
    }
  }

  static String _getEmulatorHost() {
    if (kIsWeb) return 'localhost';
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2'; // Android emulator localhost
    return 'localhost';
  }
}

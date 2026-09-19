import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class DiagnosticsResult {
  final bool success;
  final String message;
  final String details;

  DiagnosticsResult({required this.success, required this.message, required this.details});
}

class DiagnosticsService {
  final FirebaseService _firebase = FirebaseService();

  Future<DiagnosticsResult> testFirestoreRules() async {
    try {
      // We are unauthenticated (or trying an unauthorized read).
      // According to M1 deny-by-default rules, reading votingEvents should fail.
      await _firebase.firestore.collection('votingEvents').limit(1).get(const GetOptions(source: Source.server));
      
      // If we reach here, the rules FAILED to block the request.
      return DiagnosticsResult(
        success: false, 
        message: 'Firestore Rules Test Failed', 
        details: 'Expected permission-denied, but the read was allowed.'
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return DiagnosticsResult(
          success: true, 
          message: 'Firestore Rules Test Passed', 
          details: 'Successfully blocked unauthorized read (permission-denied).'
        );
      }
      return DiagnosticsResult(
        success: false, 
        message: 'Firestore Rules Test Error', 
        details: 'Unexpected error: ${e.code}'
      );
    } catch (e) {
      return DiagnosticsResult(
        success: false, 
        message: 'Firestore Rules Test Error', 
        details: e.toString()
      );
    }
  }

  Future<DiagnosticsResult> testFunctionsPing() async {
    try {
      final result = await _firebase.functions.httpsCallable('ping').call();
      final data = result.data as Map<dynamic, dynamic>?;
      
      if (data != null && 
          data['status'] == 'success' && 
          data['message'] == 'pong' && 
          data['timestamp'] != null) {
        return DiagnosticsResult(
          success: true, 
          message: 'Cloud Functions Test Passed', 
          details: 'Successfully received pong with timestamp: ${data['timestamp']}'
        );
      }
      return DiagnosticsResult(
        success: false, 
        message: 'Cloud Functions Test Failed', 
        details: 'Received an invalid payload from ping().'
      );
    } catch (e) {
      return DiagnosticsResult(
        success: false, 
        message: 'Cloud Functions Test Error', 
        details: e.toString()
      );
    }
  }

  Future<DiagnosticsResult> testAuthEmulator() async {
    try {
      // Create a temporary user to verify the Auth Emulator is accepting requests
      final email = 'diagnostic_${DateTime.now().millisecondsSinceEpoch}@securevote.test';
      final credential = await _firebase.auth.createUserWithEmailAndPassword(
        email: email,
        password: 'DiagnosticPassword123!',
      );
      
      if (credential.user != null) {
        // Clean up the test user immediately
        await credential.user!.delete();
        return DiagnosticsResult(
          success: true, 
          message: 'Auth Emulator Test Passed', 
          details: 'Successfully connected and executed an auth transaction.'
        );
      }
      return DiagnosticsResult(
        success: false, 
        message: 'Auth Emulator Test Failed', 
        details: 'User credential returned null.'
      );
    } on FirebaseAuthException catch (e) {
      return DiagnosticsResult(
        success: false, 
        message: 'Auth Emulator Test Error', 
        details: 'Firebase Auth Error: ${e.code}'
      );
    } catch (e) {
      return DiagnosticsResult(
        success: false, 
        message: 'Auth Emulator Test Error', 
        details: e.toString()
      );
    }
  }

  Future<List<DiagnosticsResult>> runAllDiagnostics() async {
    final authResult = await testAuthEmulator();
    final firestoreResult = await testFirestoreRules();
    final functionsResult = await testFunctionsPing();
    
    return [authResult, firestoreResult, functionsResult];
  }
}

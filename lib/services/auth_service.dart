import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseService _firebase = FirebaseService();

  User? get currentUser => _firebase.auth.currentUser;

  Stream<User?> get authStateChanges => _firebase.auth.authStateChanges();

  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebase.auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.reload();
      // Force-refresh the ID token so Firestore receives fresh auth token claims
      await credential.user!.getIdToken(true);
    }

    return credential;
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final credential = await _firebase.auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      // Complete registration securely via backend function
      await _firebase.functions.httpsCallable('completeRegistration').call({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      });
      // Optionally update local auth cache
      await credential.user!.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
      
      // Automatically trigger initial email verification
      await sendEmailVerification();
    }
  }

  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
      // Force-refresh the ID token so Firestore receives fresh auth token claims
      await user.getIdToken(true);
      return currentUser?.emailVerified ?? false;
    }
    return false;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    try {
      await _firebase.auth.sendPasswordResetEmail(email: trimmedEmail);
    } on FirebaseAuthException catch (e) {
      // Avoid account enumeration: treat user-not-found gracefully without revealing account non-existence
      if (e.code == 'user-not-found') {
        return;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebase.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

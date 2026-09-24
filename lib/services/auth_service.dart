import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // Cancelled by user

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      final userCredential = await _firebase.auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if Firestore user document exists, if not, complete registration
        final userDoc = await _firebase.firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          final names = (user.displayName ?? 'Google User').trim().split(' ');
          final firstName = names.first;
          final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

          await _firebase.functions.httpsCallable('completeRegistration').call({
            'firstName': firstName,
            'lastName': lastName,
          });

          // Set photoUrl from google photo if present, but do not overwrite later
          if (user.photoURL != null) {
            await _firebase.firestore
                .collection('users')
                .doc(user.uid)
                .update({'photoUrl': user.photoURL});
          }
        }

        await user.reload();
        await user.getIdToken(true);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception('An account already exists with this email using a different sign-in method.');
      }
      rethrow;
    }
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    if (!hasPasswordProvider || user.email == null) {
      throw Exception('Password change is not available for Google-only or non-password accounts.');
    }

    try {
      // 1. Reauthenticate (Exact string match, no trimming)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Update Password (Exact string match, no trimming)
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Current password is incorrect.');
      } else if (e.code == 'weak-password') {
        throw Exception('New password is too weak. Please choose a stronger password.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception('Please sign out and sign in again before changing your password.');
      } else {
        throw Exception('Failed to update password: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred while updating password.');
    }
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    try {
      try {
        await _firebase.firestore.collection('users').doc(user.uid).delete();
      } catch (_) {}

      await GoogleSignIn().signOut().catchError((_) => null);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('For security reasons, please sign out and sign back in before deleting your account.');
      }
      throw Exception(e.message ?? 'Failed to delete account.');
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _firebase.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

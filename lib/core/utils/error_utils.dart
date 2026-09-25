import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String mapFirebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'user-disabled':
      return 'This account has been disabled by an administrator.';
    case 'too-many-requests':
      return 'Too many failed attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Please check your internet connection.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    default:
      return error.message ?? 'Authentication failed.';
  }
}

String mapFirebaseFunctionsError(dynamic error) {
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    final detailMessage = switch (details) {
      String message when message.trim().isNotEmpty => message.trim(),
      Map details
          when details['message'] is String &&
              (details['message'] as String).trim().isNotEmpty =>
        (details['message'] as String).trim(),
      _ => null,
    };
    final functionMessage = error.message?.trim();
    final usefulMessage = detailMessage ??
        (functionMessage != null &&
                functionMessage.isNotEmpty &&
                functionMessage.toLowerCase() != error.code.toLowerCase()
            ? functionMessage
            : null);

    switch (error.code) {
      case 'unauthenticated':
        return 'You must be signed in to perform this action.';
      case 'permission-denied':
        return error.message ?? 'You do not have permission for this action.';
      case 'invalid-argument':
        return error.message ?? 'Invalid request parameter.';
      case 'failed-precondition':
        return error.message ??
            'This request cannot be completed in the current state.';
      case 'already-exists':
        return error.message ?? 'Resource already exists.';
      case 'resource-exhausted':
        return 'Too many failed attempts. Please wait 5 minutes before trying again.';
      case 'internal':
        return usefulMessage ??
            'The server could not complete this request. Please try again shortly.';
      default:
        return error.message ?? 'Unable to process request. Please try again.';
    }
  }
  return error.toString();
}

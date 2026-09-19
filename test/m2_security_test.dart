import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/core/utils/error_utils.dart';
import 'package:secure_e_voting/core/utils/validators.dart';

void main() {
  group('Milestone 2 Security Utility Tests', () {
    test('mapFirebaseAuthError prevents user enumeration on user-not-found', () {
      final error = FirebaseAuthException(code: 'user-not-found');
      final mapped = mapFirebaseAuthError(error);
      
      // Must map to generic invalid credential error
      expect(mapped, equals('Invalid email or password.'));
      expect(mapped.contains('exist'), isFalse);
    });

    test('mapFirebaseAuthError handles account disabled security mapping', () {
      final error = FirebaseAuthException(code: 'user-disabled');
      final mapped = mapFirebaseAuthError(error);
      
      expect(mapped, equals('This account has been disabled by an administrator.'));
    });

    test('Validators reject malicious or invalid email formats', () {
      expect(Validators.email(''), equals('Email is required'));
      expect(Validators.email('not_an_email'), equals('Enter a valid email address'));
      expect(Validators.email('hacker<script>@test.com'), equals('Enter a valid email address'));
      expect(Validators.email('valid.user@securevote.com'), isNull);
    });

    test('Validators enforce minimum password length >= 6', () {
      expect(Validators.password('12345'), equals('Password must be at least 6 characters'));
      expect(Validators.password('123456'), isNull);
    });
  });
}

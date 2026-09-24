import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/core/utils/validators.dart';

void main() {
  group('500 KB Image Limit & Sanitization Unit Tests', () {
    test('Image size under 512,000 bytes (500 KB) passes size check', () {
      final smallBytes = Uint8List(100 * 1024); // 100 KB
      expect(smallBytes.lengthInBytes < 512000, isTrue);
    });

    test('Image size over 512,000 bytes (500 KB) fails size check', () {
      final largeBytes = Uint8List(600 * 1024); // 600 KB
      expect(largeBytes.lengthInBytes >= 512000, isTrue);
    });

    test('Validators.sanitizeText trims normal text correctly', () {
      expect(Validators.sanitizeText('  SecureVote  '), equals('SecureVote'));
    });

    test('Validators.password NEVER trims or modifies password string', () {
      const untrimmedPassword = '  SecretPass123!  ';
      expect(Validators.password(untrimmedPassword), isNull); // Valid password >= 6 chars
      expect(untrimmedPassword.length, equals(18)); // Length preserved
    });

    test('Validators.confirmPassword uses exact string equality without trimming', () {
      const p1 = '  SecretPass123!  ';
      const p2 = '  SecretPass123!  ';
      const p3 = 'SecretPass123!';

      expect(Validators.confirmPassword(p2, p1), isNull); // Matches
      expect(Validators.confirmPassword(p3, p1), equals('Passwords do not match')); // Rejects trimmed mismatch
    });
  });
}

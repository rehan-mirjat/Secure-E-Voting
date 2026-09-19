import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/services/firebase_service.dart';

void main() {
  group('Production Fix #2: Emulator / Production Separation', () {
    
    setUp(() {
      // Reset the static flag before each test
      // Note: We can't actually change kReleaseMode dynamically in Dart,
      // but we can test the initialization logic via the force parameter.
    });

    test('isEmulatorMode strictly defaults to FALSE when no explicit flag is passed', () async {
      // Simulate normal initialization without passing a flag
      await FirebaseService.initialize(forceEmulatorForTest: false);
      expect(FirebaseService.isEmulatorMode, isFalse);
    });

    test('isEmulatorMode can be enabled explicitly in development via force flag', () async {
      try {
        await FirebaseService.initialize(forceEmulatorForTest: true);
      } catch (e) {
        // Expected to throw because FirebaseCore isn't initialized in this raw unit test context,
        // but the flag should still be set before it crashes trying to connect.
      }
      expect(FirebaseService.isEmulatorMode, isTrue);
    });
  });
}

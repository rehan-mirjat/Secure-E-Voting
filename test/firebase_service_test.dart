import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/services/firebase_service.dart';

void main() {
  group('Firebase environment selection', () {
    test('defaults to the production Firebase connection', () async {
      await FirebaseService.initialize(forceEmulatorForTest: false);
      expect(FirebaseService.isEmulatorMode, isFalse);
    });
  });
}

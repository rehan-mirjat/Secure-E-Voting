import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/core/utils/error_utils.dart';

void main() {
  group('OrganizationRepository Error Hardening Tests', () {
    test('mapFirebaseFunctionsError maps all standard error codes safely', () {
      final unauthErr = FirebaseFunctionsException(code: 'unauthenticated', message: 'Auth required');
      final permErr = FirebaseFunctionsException(code: 'permission-denied', message: 'Access denied');
      final invalidErr = FirebaseFunctionsException(code: 'invalid-argument', message: 'Name too short');
      final precondErr = FirebaseFunctionsException(code: 'failed-precondition', message: 'Invitation expired');
      final existErr = FirebaseFunctionsException(code: 'already-exists', message: 'Already a member');
      final exhaustErr = FirebaseFunctionsException(code: 'resource-exhausted', message: 'Rate limit');
      final internalErr = FirebaseFunctionsException(code: 'internal', message: 'Internal stack error');

      expect(mapFirebaseFunctionsError(unauthErr), equals('You must be signed in to perform this action.'));
      expect(mapFirebaseFunctionsError(permErr), equals('Access denied'));
      expect(mapFirebaseFunctionsError(invalidErr), equals('Name too short'));
      expect(mapFirebaseFunctionsError(precondErr), equals('Invitation expired'));
      expect(mapFirebaseFunctionsError(existErr), equals('Already a member'));
      expect(mapFirebaseFunctionsError(exhaustErr), equals('Too many failed attempts. Please wait 5 minutes before trying again.'));
      expect(mapFirebaseFunctionsError(internalErr), equals('Internal stack error'));
    });
  });
}

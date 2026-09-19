import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/departments/data/department_repository.dart';
import 'package:secure_e_voting/services/firebase_service.dart';

class InterceptedCall {
  final String functionName;
  final dynamic parameters;

  InterceptedCall({required this.functionName, required this.parameters});
}

class FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  @override
  final T data;

  FakeHttpsCallableResult(this.data);
}

class FakeHttpsCallable implements HttpsCallable {
  final String functionName;
  final List<InterceptedCall> log;
  final Map<String, dynamic> mockResponseData;
  final FirebaseFunctionsException? mockException;

  FakeHttpsCallable({
    required this.functionName,
    required this.log,
    required this.mockResponseData,
    this.mockException,
  });

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    log.add(InterceptedCall(functionName: functionName, parameters: parameters));
    if (mockException != null) {
      throw mockException!;
    }
    return FakeHttpsCallableResult<T>(mockResponseData as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseFunctions implements FirebaseFunctions {
  final List<InterceptedCall> callLog = [];
  Map<String, dynamic> nextResponseData = {'status': 'success'};
  FirebaseFunctionsException? nextException;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return FakeHttpsCallable(
      functionName: name,
      log: callLog,
      mockResponseData: nextResponseData,
      mockException: nextException,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseService implements FirebaseService {
  final FakeFirebaseFunctions fakeFunctions = FakeFirebaseFunctions();

  @override
  FirebaseFunctions get functions => fakeFunctions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DepartmentRepository Intercepted Payload Hardening Tests', () {
    test('createDepartment sends ONLY permitted input fields', () async {
      final fakeService = FakeFirebaseService();
      fakeService.fakeFunctions.nextResponseData = {
        'status': 'success',
        'departmentId': 'dept_123',
      };

      final repo = DepartmentRepository(firebase: fakeService);
      final deptId = await repo.createDepartment(
        organizationId: 'org_123',
        name: 'Computer Science',
        description: 'CS Dept',
      );

      expect(deptId, equals('dept_123'));
      expect(fakeService.fakeFunctions.callLog.length, equals(1));

      final call = fakeService.fakeFunctions.callLog.first;
      expect(call.functionName, equals('createDepartment'));

      final payload = call.parameters as Map<String, dynamic>;
      expect(payload.keys.length, equals(3));
      expect(payload['organizationId'], equals('org_123'));
      expect(payload['name'], equals('Computer Science'));
      expect(payload['description'], equals('CS Dept'));
    });

    test('updateDepartment sends ONLY permitted input fields', () async {
      final fakeService = FakeFirebaseService();
      final repo = DepartmentRepository(firebase: fakeService);
      
      await repo.updateDepartment(
        departmentId: 'dept_123',
        name: 'New Name',
        description: 'New Desc',
      );

      expect(fakeService.fakeFunctions.callLog.length, equals(1));
      final call = fakeService.fakeFunctions.callLog.first;
      expect(call.functionName, equals('updateDepartment'));

      final payload = call.parameters as Map<String, dynamic>;
      expect(payload.keys.length, equals(3));
      expect(payload['departmentId'], equals('dept_123'));
      expect(payload['name'], equals('New Name'));
      expect(payload['description'], equals('New Desc'));
    });

    test('deleteDepartment sends ONLY departmentId parameter', () async {
      final fakeService = FakeFirebaseService();
      final repo = DepartmentRepository(firebase: fakeService);
      
      await repo.deleteDepartment('dept_123');

      expect(fakeService.fakeFunctions.callLog.length, equals(1));
      final call = fakeService.fakeFunctions.callLog.first;
      expect(call.functionName, equals('deleteDepartment'));

      final payload = call.parameters as Map<String, dynamic>;
      expect(payload.keys.length, equals(1));
      expect(payload['departmentId'], equals('dept_123'));
    });

    test('assignMemberToDepartment sends ONLY permitted fields', () async {
      final fakeService = FakeFirebaseService();
      final repo = DepartmentRepository(firebase: fakeService);
      
      await repo.assignMemberToDepartment(
        organizationId: 'org_123',
        targetUid: 'user_456',
        departmentId: 'dept_123',
      );

      expect(fakeService.fakeFunctions.callLog.length, equals(1));
      final call = fakeService.fakeFunctions.callLog.first;
      expect(call.functionName, equals('assignMemberToDepartment'));

      final payload = call.parameters as Map<String, dynamic>;
      expect(payload.keys.length, equals(3));
      expect(payload['organizationId'], equals('org_123'));
      expect(payload['targetUid'], equals('user_456'));
      expect(payload['departmentId'], equals('dept_123'));
    });

    test('removeMemberFromDepartment sends ONLY permitted fields', () async {
      final fakeService = FakeFirebaseService();
      final repo = DepartmentRepository(firebase: fakeService);
      
      await repo.removeMemberFromDepartment(
        organizationId: 'org_123',
        targetUid: 'user_456',
      );

      expect(fakeService.fakeFunctions.callLog.length, equals(1));
      final call = fakeService.fakeFunctions.callLog.first;
      expect(call.functionName, equals('removeMemberFromDepartment'));

      final payload = call.parameters as Map<String, dynamic>;
      expect(payload.keys.length, equals(2));
      expect(payload['organizationId'], equals('org_123'));
      expect(payload['targetUid'], equals('user_456'));
    });
  });
}

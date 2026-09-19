import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_utils.dart';
import '../../../services/firebase_service.dart';
import '../domain/department.dart';

class DepartmentRepository {
  DepartmentRepository({FirebaseService? firebase}) : _firebase = firebase ?? FirebaseService();

  final FirebaseService _firebase;

  /// Streams departments belonging to the specified organization.
  Stream<List<Department>> watchDepartments(String organizationId) {
    if (organizationId.isEmpty) return Stream.value([]);

    return _firebase.firestore
        .collection(AppConstants.departmentsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Department.fromFirestore(doc)).toList());
  }

  /// Creates a new department via server-authoritative Cloud Function.
  Future<String> createDepartment({
    required String organizationId,
    required String name,
    required String description,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('createDepartment');
      final response = await callable.call({
        'organizationId': organizationId.trim(),
        'name': name.trim(),
        'description': description.trim(),
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['departmentId'] != null) {
        return data['departmentId'] as String;
      }
      throw Exception('Unable to create department. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to create department. Please try again.');
    }
  }

  /// Updates an existing department via server-authoritative Cloud Function.
  Future<void> updateDepartment({
    required String departmentId,
    String? name,
    String? description,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('updateDepartment');
      await callable.call({
        'departmentId': departmentId.trim(),
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to update department. Please try again.');
    }
  }

  /// Deletes a department via server-authoritative Cloud Function.
  Future<void> deleteDepartment(String departmentId) async {
    try {
      final callable = _firebase.functions.httpsCallable('deleteDepartment');
      await callable.call({
        'departmentId': departmentId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to delete department. Please try again.');
    }
  }

  /// Assigns a member to a department via server-authoritative Cloud Function.
  Future<void> assignMemberToDepartment({
    required String organizationId,
    required String targetUid,
    required String departmentId,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('assignMemberToDepartment');
      await callable.call({
        'organizationId': organizationId.trim(),
        'targetUid': targetUid.trim(),
        'departmentId': departmentId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to assign department. Please try again.');
    }
  }

  /// Removes a member from their assigned department via server-authoritative Cloud Function.
  Future<void> removeMemberFromDepartment({
    required String organizationId,
    required String targetUid,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('removeMemberFromDepartment');
      await callable.call({
        'organizationId': organizationId.trim(),
        'targetUid': targetUid.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to remove department assignment. Please try again.');
    }
  }
}

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository();
});

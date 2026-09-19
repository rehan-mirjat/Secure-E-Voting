import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/error_utils.dart';
import '../domain/voting_event.dart';

class VotingEventRepository {
  final FirebaseService _firebase = FirebaseService();

  Future<String> createVotingEvent({
    required String organizationId,
    required String title,
    required String description,
    required String votingType,
    required String eligibilityType,
    List<String>? eligibilityDepartmentIds,
    List<String>? eligibilityUserIds,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('createVotingEvent');
      final result = await callable.call({
        'organizationId': organizationId,
        'title': title,
        'description': description,
        'votingType': votingType,
        'eligibilityType': eligibilityType,
        if (eligibilityDepartmentIds != null) 'eligibilityDepartmentIds': eligibilityDepartmentIds,
        if (eligibilityUserIds != null) 'eligibilityUserIds': eligibilityUserIds,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
      });
      return result.data['eventId'] as String;
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> updateVotingEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    String? eligibilityType,
    List<String>? eligibilityDepartmentIds,
    List<String>? eligibilityUserIds,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('updateVotingEvent');
      final payload = <String, dynamic>{
        'eventId': eventId,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startAt != null) 'startAt': startAt.toUtc().toIso8601String(),
        if (endAt != null) 'endAt': endAt.toUtc().toIso8601String(),
        if (eligibilityType != null) 'eligibilityType': eligibilityType,
        if (eligibilityDepartmentIds != null) 'eligibilityDepartmentIds': eligibilityDepartmentIds,
        if (eligibilityUserIds != null) 'eligibilityUserIds': eligibilityUserIds,
      };
      await callable.call(payload);
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> publishVotingEvent(String eventId) async {
    try {
      final callable = _firebase.functions.httpsCallable('publishVotingEvent');
      await callable.call({'eventId': eventId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> deleteVotingEvent(String eventId) async {
    try {
      final callable = _firebase.functions.httpsCallable('deleteVotingEvent');
      await callable.call({'eventId': eventId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> cancelVotingEvent(String eventId) async {
    try {
      final callable = _firebase.functions.httpsCallable('cancelVotingEvent');
      await callable.call({'eventId': eventId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> closeVotingEvent(String eventId) async {
    try {
      final callable = _firebase.functions.httpsCallable('closeVotingEvent');
      await callable.call({'eventId': eventId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Stream<List<VotingEvent>> watchOrganizationVotingEvents(String organizationId) {
    return _firebase.firestore
        .collection('votingEvents')
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => VotingEvent.fromFirestore(doc)).toList());
  }

  Stream<VotingEvent?> watchVotingEvent(String eventId) {
    return _firebase.firestore
        .collection('votingEvents')
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.exists ? VotingEvent.fromFirestore(doc) : null);
  }
}

final votingEventRepositoryProvider = Provider((ref) => VotingEventRepository());

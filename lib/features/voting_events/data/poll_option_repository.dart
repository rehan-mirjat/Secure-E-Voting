import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/error_utils.dart';
import '../domain/poll_option.dart';

class PollOptionRepository {
  final FirebaseService _firebase = FirebaseService();

  Future<void> createPollOption({
    required String organizationId,
    required String votingEventId,
    required String label,
    String? description,
    int? sortOrder,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('createPollOption');
      await callable.call({
        'organizationId': organizationId,
        'votingEventId': votingEventId,
        'label': label,
        if (description != null && description.isNotEmpty) 'description': description,
        if (sortOrder != null) 'sortOrder': sortOrder,
      });
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> updatePollOption({
    required String optionId,
    String? label,
    String? description,
    int? sortOrder,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('updatePollOption');
      await callable.call({
        'optionId': optionId,
        if (label != null) 'label': label,
        if (description != null) 'description': description,
        if (sortOrder != null) 'sortOrder': sortOrder,
      });
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> deletePollOption(String optionId) async {
    try {
      final callable = _firebase.functions.httpsCallable('deletePollOption');
      await callable.call({'optionId': optionId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Stream<List<PollOption>> watchEventPollOptions(String eventId) {
    return _firebase.firestore
        .collection('pollOptions')
        .where('votingEventId', isEqualTo: eventId)
        .orderBy('sortOrder')
        .orderBy('id')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PollOption.fromFirestore(doc)).toList());
  }
}

final pollOptionRepositoryProvider = Provider((ref) => PollOptionRepository());

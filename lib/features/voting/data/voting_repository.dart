import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase_service.dart';
import '../domain/vote_receipt.dart';

class UserParticipationParams {
  final String organizationId;
  final String eventId;
  final String userId;

  const UserParticipationParams({
    required this.organizationId,
    required this.eventId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserParticipationParams &&
          runtimeType == other.runtimeType &&
          organizationId == other.organizationId &&
          eventId == other.eventId &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(organizationId, eventId, userId);
}

class VotingRepository {
  final FirebaseService _firebase = FirebaseService();

  /// Invokes the server-authoritative [castVote] Cloud Function inside a single transaction.
  Future<VoteReceipt> castVote({
    required String organizationId,
    required String eventId,
    String? candidateId,
    String? pollOptionId,
  }) async {
    final callable = _firebase.functions.httpsCallable('castVote');
    
    final payload = <String, dynamic>{
      'organizationId': organizationId,
      'eventId': eventId,
    };
    
    if (candidateId != null && candidateId.isNotEmpty) {
      payload['candidateId'] = candidateId;
    }
    if (pollOptionId != null && pollOptionId.isNotEmpty) {
      payload['pollOptionId'] = pollOptionId;
    }

    try {
      final response = await callable.call(payload);
      final data = response.data as Map<String, dynamic>;

      return VoteReceipt(
        receiptId: data['receiptId'] as String? ?? '',
        organizationId: organizationId,
        votingEventId: eventId,
        userId: _firebase.auth.currentUser?.uid ?? '',
        votedAt: data['votedAt'] != null 
            ? DateTime.parse(data['votedAt'] as String) 
            : DateTime.now(),
        receiptHash: data['receiptHash'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to submit ballot.');
    } catch (e) {
      throw Exception('Failed to cast ballot: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  /// Checks whether the user has already participated in this specific voting event.
  Stream<bool> watchUserParticipation({
    required String organizationId,
    required String eventId,
    required String userId,
  }) {
    if (userId.isEmpty || organizationId.isEmpty || eventId.isEmpty) {
      return Stream.value(false);
    }

    final docId = '${organizationId}_${eventId}_$userId';
    return _firebase.firestore
        .collection('participation')
        .doc(docId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  /// Fetches the vote receipt for a given event and user.
  Future<VoteReceipt?> getUserReceipt({
    required String organizationId,
    required String eventId,
    required String userId,
  }) async {
    if (userId.isEmpty || eventId.isEmpty) return null;

    final querySnap = await _firebase.firestore
        .collection('voteReceipts')
        .where('organizationId', isEqualTo: organizationId)
        .where('votingEventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (querySnap.docs.isEmpty) return null;
    final docData = querySnap.docs.first.data();
    return VoteReceipt.fromMap(docData, querySnap.docs.first.id);
  }
}

final votingRepositoryProvider = Provider<VotingRepository>((ref) {
  return VotingRepository();
});

final userParticipationProvider = StreamProvider.family<bool, UserParticipationParams>((ref, params) {
  return ref.watch(votingRepositoryProvider).watchUserParticipation(
        organizationId: params.organizationId,
        eventId: params.eventId,
        userId: params.userId,
      );
});

final userReceiptProvider = FutureProvider.family<VoteReceipt?, UserParticipationParams>((ref, params) async {
  return ref.watch(votingRepositoryProvider).getUserReceipt(
        organizationId: params.organizationId,
        eventId: params.eventId,
        userId: params.userId,
      );
});

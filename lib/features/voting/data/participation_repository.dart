import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase_service.dart';

class ParticipationRepository {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  Future<bool> hasUserVoted(String organizationId, String eventId, String userId) async {
    final docId = '${organizationId}_${eventId}_$userId';
    final doc = await _firestore.collection('participation').doc(docId).get();
    return doc.exists;
  }
}

final participationRepositoryProvider = Provider<ParticipationRepository>((ref) {
  return ParticipationRepository();
});

final participationStatusProvider = FutureProvider.family<bool, ({String organizationId, String eventId, String userId})>((ref, args) {
  final repo = ref.watch(participationRepositoryProvider);
  return repo.hasUserVoted(args.organizationId, args.eventId, args.userId);
});

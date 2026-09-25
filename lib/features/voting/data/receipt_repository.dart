import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase_service.dart';
import '../domain/vote_receipt.dart';

class ReceiptRepository {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  Future<VoteReceipt?> getReceiptForEvent(String eventId, String userId) async {
    final query = await _firestore
        .collection('voteReceipts')
        .where('userId', isEqualTo: userId)
        .where('votingEventId', isEqualTo: eventId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return VoteReceipt.fromMap(query.docs.first.data(), query.docs.first.id);
  }
}

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository();
});

final receiptForEventProvider = FutureProvider.family<VoteReceipt?, ({String eventId, String userId})>((ref, args) {
  final repo = ref.watch(receiptRepositoryProvider);
  return repo.getReceiptForEvent(args.eventId, args.userId);
});

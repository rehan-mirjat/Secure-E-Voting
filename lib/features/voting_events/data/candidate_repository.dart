import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/firebase_service.dart';
import '../../../core/utils/error_utils.dart';
import '../domain/candidate.dart';

class CandidateRepository {
  final FirebaseService _firebase = FirebaseService();

  Future<void> createCandidateWithPhoto({
    required String organizationId,
    required String votingEventId,
    required String name,
    String? party,
    String? bio,
    Uint8List? photoBytes,
  }) async {
    try {
      final createCallable = _firebase.functions.httpsCallable('createCandidate');
      final result = await createCallable.call({
        'organizationId': organizationId,
        'votingEventId': votingEventId,
        'name': name,
        if (party != null && party.isNotEmpty) 'party': party,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
      });

      final candidateId = result.data['candidateId'] as String;
      final expectedPhotoPath = result.data['expectedPhotoPath'] as String?;

      if (photoBytes != null && expectedPhotoPath != null) {
        // Upload photo
        final storageRef = FirebaseStorage.instance.ref().child(expectedPhotoPath);
        await storageRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));

        // Finalize photo
        final finalizeCallable = _firebase.functions.httpsCallable('finalizeCandidatePhoto');
        await finalizeCallable.call({'candidateId': candidateId});
      }
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> updateCandidate({
    required String candidateId,
    String? name,
    String? party,
    String? bio,
    Uint8List? newPhotoBytes,
    String? expectedPhotoPath, // Required if uploading a new photo
  }) async {
    try {
      final updateCallable = _firebase.functions.httpsCallable('updateCandidate');
      await updateCallable.call({
        'candidateId': candidateId,
        if (name != null) 'name': name,
        if (party != null) 'party': party,
        if (bio != null) 'bio': bio,
      });

      if (newPhotoBytes != null && expectedPhotoPath != null) {
        final deletePhotoCallable = _firebase.functions.httpsCallable('deleteCandidatePhoto');
        try {
           await deletePhotoCallable.call({'candidateId': candidateId});
        } catch (_) {
           // Ignore errors if no photo existed previously
        }

        final storageRef = FirebaseStorage.instance.ref().child(expectedPhotoPath);
        await storageRef.putData(newPhotoBytes, SettableMetadata(contentType: 'image/jpeg'));

        final finalizeCallable = _firebase.functions.httpsCallable('finalizeCandidatePhoto');
        await finalizeCallable.call({'candidateId': candidateId});
      }
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> deleteCandidatePhoto(String candidateId) async {
    try {
      final callable = _firebase.functions.httpsCallable('deleteCandidatePhoto');
      await callable.call({'candidateId': candidateId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Future<void> deleteCandidate(String candidateId) async {
    try {
      final callable = _firebase.functions.httpsCallable('deleteCandidate');
      await callable.call({'candidateId': candidateId});
    } catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }
  }

  Stream<List<Candidate>> watchEventCandidates(String eventId) {
    return _firebase.firestore
        .collection('candidates')
        .where('votingEventId', isEqualTo: eventId)
        .orderBy('name') // FR-CAN-06
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Candidate.fromFirestore(doc)).toList());
  }
}

final candidateRepositoryProvider = Provider((ref) => CandidateRepository());

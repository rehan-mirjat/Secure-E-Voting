import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/firebase_service.dart';
import '../domain/app_user.dart';

class UserRepository {
  final FirebaseService _firebase = FirebaseService();

  Stream<AppUser?> watchUserProfile(String uid) {
    return _firebase.firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  Future<void> updateProfile({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {
    final trimmedFirst = firstName.trim();
    final trimmedLast = lastName.trim();
    final displayName = '$trimmedFirst $trimmedLast';

    await _firebase.firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'firstName': trimmedFirst,
      'lastName': trimmedLast,
      'displayName': displayName,
    });
  }

  Future<String> uploadProfilePhoto({
    required String uid,
    required List<int> imageBytes,
    required String fileExtension,
  }) async {
    final currentUser = _firebase.auth.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      throw Exception('Unauthorized profile photo update.');
    }

    // Enforce 500 KB (512,000 bytes) limit
    if (imageBytes.length > 512000) {
      throw Exception(
          'Profile photo exceeds 500 KB size limit (512,000 bytes).');
    }

    const supportedTypes = {'jpg', 'png', 'webp'};
    if (!supportedTypes.contains(fileExtension)) {
      throw Exception('Choose a JPEG, PNG, or WebP image.');
    }
    final contentType = switch (fileExtension) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw Exception('Choose a JPEG, PNG, or WebP image.'),
    };

    // Keep the object extension and response MIME type aligned so desktop
    // browsers can decode the uploaded image reliably.
    final storageRef = _firebase.storage
        .ref()
        .child('users/$uid/profile/avatar.$fileExtension');
    final uploadTask = await storageRef.putData(
      Uint8List.fromList(imageBytes),
      SettableMetadata(contentType: contentType),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Update Firestore
    await _firebase.firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'photoUrl': downloadUrl,
    });

    return downloadUrl;
  }
}

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository());

final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUserProfile(uid);
});

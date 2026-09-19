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
}

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUserProfile(uid);
});

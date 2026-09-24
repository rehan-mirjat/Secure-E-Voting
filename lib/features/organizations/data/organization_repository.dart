import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_utils.dart';
import '../../../services/firebase_service.dart';
import '../domain/organization.dart';
import '../domain/organization_member.dart';

class OrganizationRepository {
  OrganizationRepository({FirebaseService? firebase, Uuid? uuid})
      : _firebase = firebase ?? FirebaseService(),
        _uuid = uuid ?? const Uuid();

  final FirebaseService _firebase;
  final Uuid _uuid;

  /// Creates a new Organization via the server-authoritative [createOrganization] Cloud Function.
  Future<String> createOrganization({
    required String name,
    required String type,
    required String description,
    required String email,
    required String country,
    required String city,
    String? website,
    String? logoUrl,
  }) async {
    final requestId = _uuid.v4();

    try {
      final callable = _firebase.functions.httpsCallable('createOrganization');
      final response = await callable.call({
        'requestId': requestId,
        'name': name.trim(),
        'type': type.trim(),
        'description': description.trim(),
        'email': email.trim(),
        'country': country.trim(),
        'city': city.trim(),
        if (website != null && website.trim().isNotEmpty) 'website': website.trim(),
        if (logoUrl != null && logoUrl.trim().isNotEmpty) 'logoUrl': logoUrl.trim(),
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['organizationId'] != null) {
        return data['organizationId'] as String;
      }
      throw Exception('Unable to create organization. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to create organization. Please try again.');
    }
  }

  /// Joins an Organization using a raw joining code via [joinOrganizationWithCode] Cloud Function.
  Future<({String organizationId, String organizationName})> joinOrganizationWithCode(String rawCode) async {
    final trimmedCode = rawCode.trim();
    if (trimmedCode.isEmpty) {
      throw Exception('Please enter a valid joining code.');
    }

    try {
      final callable = _firebase.functions.httpsCallable('joinOrganizationWithCode');
      final response = await callable.call({
        'rawCode': trimmedCode,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['organizationId'] != null) {
        return (
          organizationId: data['organizationId'] as String,
          organizationName: (data['organizationName'] as String?) ?? 'Organization',
        );
      }
      throw Exception('Unable to join organization. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to join organization. Please try again.');
    }
  }

  /// Invites a user by email via [inviteMember] Cloud Function.
  Future<({String rawToken, String invitationId, String email})> inviteMember({
    required String organizationId,
    required String email,
    required String role,
    int expiresInHours = 168,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('inviteMember');
      final response = await callable.call({
        'organizationId': organizationId.trim(),
        'email': email.trim(),
        'role': role.trim(),
        'expiresInHours': expiresInHours,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['rawToken'] != null) {
        return (
          rawToken: data['rawToken'] as String,
          invitationId: (data['invitationId'] as String?) ?? '',
          email: (data['email'] as String?) ?? email,
        );
      }
      throw Exception('Unable to send invitation. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to send invitation. Please try again.');
    }
  }

  /// Accepts an invitation token via [acceptInvitation] Cloud Function.
  Future<({String organizationId, String organizationName})> acceptInvitation(String rawToken) async {
    final trimmedToken = rawToken.trim();
    if (trimmedToken.isEmpty) {
      throw Exception('Please enter a valid invitation token.');
    }

    try {
      final callable = _firebase.functions.httpsCallable('acceptInvitation');
      final response = await callable.call({
        'rawToken': trimmedToken,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['organizationId'] != null) {
        return (
          organizationId: data['organizationId'] as String,
          organizationName: (data['organizationName'] as String?) ?? 'Organization',
        );
      }
      throw Exception('Unable to accept invitation. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to accept invitation. Please try again.');
    }
  }

  /// Revokes an invitation via [revokeInvitation] Cloud Function.
  Future<void> revokeInvitation(String invitationId) async {
    try {
      final callable = _firebase.functions.httpsCallable('revokeInvitation');
      await callable.call({
        'invitationId': invitationId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to revoke invitation. Please try again.');
    }
  }

  /// Fetches pending invitations for an organization securely via [getPendingInvitations] Cloud Function.
  Future<List<Map<String, dynamic>>> getPendingInvitations(String organizationId) async {
    try {
      final callable = _firebase.functions.httpsCallable('getPendingInvitations');
      final response = await callable.call({
        'organizationId': organizationId,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['invitations'] != null) {
        final list = data['invitations'] as List<dynamic>;
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to fetch pending invitations.');
    }
  }

  /// Fetches paginated organization members securely via [getOrganizationMembers] Cloud Function.
  Future<({List<Map<String, dynamic>> members, String? nextPageToken})> getOrganizationMembers({
    required String organizationId,
    int pageSize = 50,
    String? pageToken,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('getOrganizationMembers');
      final response = await callable.call({
        'organizationId': organizationId.trim(),
        'pageSize': pageSize,
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null && data['status'] == 'success' && data['members'] != null) {
        final rawList = data['members'] as List<dynamic>;
        final members = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        return (
          members: members,
          nextPageToken: data['nextPageToken'] as String?,
        );
      }
      return (members: <Map<String, dynamic>>[], nextPageToken: null);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to fetch organization members.');
    }
  }

  /// Updates a member's role via [updateMemberRole] Cloud Function.
  Future<void> updateMemberRole({
    required String organizationId,
    required String targetUid,
    required String newRole,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('updateMemberRole');
      await callable.call({
        'organizationId': organizationId.trim(),
        'targetUid': targetUid.trim(),
        'newRole': newRole.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to update member role.');
    }
  }

  /// Updates a member's status via [updateMemberStatus] Cloud Function.
  Future<void> updateMemberStatus({
    required String organizationId,
    required String targetUid,
    required String newStatus,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('updateMemberStatus');
      await callable.call({
        'organizationId': organizationId.trim(),
        'targetUid': targetUid.trim(),
        'newStatus': newStatus.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to update member status.');
    }
  }

  /// Removes a member via [removeMember] Cloud Function.
  Future<void> removeMember({
    required String organizationId,
    required String targetUid,
  }) async {
    try {
      final callable = _firebase.functions.httpsCallable('removeMember');
      await callable.call({
        'organizationId': organizationId.trim(),
        'targetUid': targetUid.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to remove member.');
    }
  }

  /// Voluntarily leaves an organization via [leaveOrganization] Cloud Function.
  Future<void> leaveOrganization({required String organizationId}) async {
    try {
      final callable = _firebase.functions.httpsCallable('leaveOrganization');
      await callable.call({
        'organizationId': organizationId.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to leave organization.');
    }
  }

  /// Streams active membership records for the specified user ID.
  Stream<List<OrganizationMember>> watchUserMemberships(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _firebase.firestore
        .collection(AppConstants.orgMembersCollection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: AppConstants.memberStatusActive)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrganizationMember.fromFirestore(doc))
            .toList());
  }

  /// Streams a single organization document in real-time.
  Stream<Organization?> watchOrganization(String organizationId) {
    if (organizationId.isEmpty) return Stream.value(null);

    return _firebase.firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .snapshots()
        .map((doc) => doc.exists ? Organization.fromFirestore(doc) : null);
  }

  /// Fetches a single organization document once.
  Future<Organization?> getOrganization(String organizationId) async {
    if (organizationId.isEmpty) return null;

    final doc = await _firebase.firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .get();

    return doc.exists ? Organization.fromFirestore(doc) : null;
  }

  /// Uploads an organization logo to storage and updates the organization document via Cloud Function.
  Future<String> uploadOrganizationLogo({
    required String organizationId,
    required List<int> imageBytes,
  }) async {
    final currentUser = _firebase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Unauthorized organization logo upload.');
    }

    // Enforce 500 KB (512,000 bytes) limit
    if (imageBytes.length >= 512000) {
      throw Exception('Organization logo exceeds 500 KB size limit (512,000 bytes).');
    }

    // Upload to organization-scoped path: organizations/{orgId}/logo/logo.jpg
    final storageRef = _firebase.storage.ref().child('organizations/$organizationId/logo/logo.jpg');
    final uploadTask = await storageRef.putData(
      Uint8List.fromList(imageBytes),
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Update Firestore via server-authoritative updateOrganization Cloud Function
    try {
      final callable = _firebase.functions.httpsCallable('updateOrganization');
      await callable.call({
        'organizationId': organizationId,
        'logoUrl': downloadUrl,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }

    return downloadUrl;
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

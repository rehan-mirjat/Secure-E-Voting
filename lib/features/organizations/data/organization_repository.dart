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

  /// High-performance in-memory cache for organization metadata
  final Map<String, Organization> _orgCache = {};

  void clearCache() {
    _orgCache.clear();
  }

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
        if (website != null && website.trim().isNotEmpty)
          'website': website.trim(),
        if (logoUrl != null && logoUrl.trim().isNotEmpty)
          'logoUrl': logoUrl.trim(),
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null &&
          data['status'] == 'success' &&
          data['organizationId'] != null) {
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
  Future<({String organizationId, String organizationName})>
      joinOrganizationWithCode(String rawCode) async {
    final trimmedCode = rawCode.trim();
    if (trimmedCode.isEmpty) {
      throw Exception('Please enter a valid joining code.');
    }

    try {
      final callable =
          _firebase.functions.httpsCallable('joinOrganizationWithCode');
      final response = await callable.call({
        'rawCode': trimmedCode,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null &&
          data['status'] == 'success' &&
          data['organizationId'] != null) {
        return (
          organizationId: data['organizationId'] as String,
          organizationName:
              (data['organizationName'] as String?) ?? 'Organization',
        );
      }
      throw Exception('Unable to join organization. Please try again.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    } catch (_) {
      throw Exception('Unable to join organization. Please try again.');
    }
  }

  /// Invites a user through the server-authoritative [inviteMember] function.
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
      if (data != null &&
          data['status'] == 'success' &&
          data['rawToken'] != null) {
        return (
          rawToken: data['rawToken'] as String,
          invitationId: (data['invitationId'] as String?) ?? '',
          email: (data['email'] as String?) ?? email,
        );
      }
    } on FirebaseFunctionsException catch (error) {
      final detailMessage = switch (error.details) {
        String message => message,
        Map details when details['message'] is String =>
          details['message'] as String,
        _ => null,
      };
      final messageIsGeneric =
          error.message?.trim().toLowerCase() == error.code.toLowerCase();
      final serverMessage =
          detailMessage ?? (messageIsGeneric ? null : error.message?.trim());
      final message = switch (error.code) {
        'unauthenticated' =>
          'Please sign in again before sending an invitation.',
        'permission-denied' =>
          serverMessage ?? 'You do not have permission to invite members.',
        'already-exists' => serverMessage ??
            'An active invitation already exists for this email.',
        'invalid-argument' =>
          serverMessage ?? 'Check the email address and invitation details.',
        'failed-precondition' =>
          serverMessage ?? 'Invitation service is not configured correctly.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Invitation service is unavailable. Please try again shortly.',
        'internal' => serverMessage ??
            'The invitation service could not process this request. Please try again shortly.',
        _ => serverMessage ??
            'The invitation failed (${error.code}). Please try again or contact your administrator.',
      };
      throw Exception(message);
    } catch (error) {
      throw Exception('Unable to send invitation: $error');
    }
    throw Exception(
        'Invitation service returned an invalid response. Please try again.');
  }

  /// Adds an existing verified SecureVote account directly as a regular member.
  Future<void> addMember({
    required String organizationId,
    required String email,
  }) async {
    try {
      await _firebase.functions.httpsCallable('addMember').call({
        'organizationId': organizationId.trim(),
        'email': email.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(mapFirebaseFunctionsError(error));
    } catch (_) {
      throw Exception('Unable to add this member. Please try again.');
    }
  }

  /// Accepts an invitation token via [acceptInvitation] Cloud Function.
  Future<({String organizationId, String organizationName})> acceptInvitation(
      String rawToken) async {
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
      if (data != null &&
          data['status'] == 'success' &&
          data['organizationId'] != null) {
        return (
          organizationId: data['organizationId'] as String,
          organizationName:
              (data['organizationName'] as String?) ?? 'Organization',
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

  /// Fetches pending invitations for an organization securely via [getPendingInvitations] Cloud Function,
  /// with automatic direct Firestore fallback if Cloud Function call is unavailable.
  Future<List<Map<String, dynamic>>> getPendingInvitations(
      String organizationId) async {
    try {
      final callable =
          _firebase.functions.httpsCallable('getPendingInvitations');
      final response = await callable.call({
        'organizationId': organizationId,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null &&
          data['status'] == 'success' &&
          data['invitations'] != null) {
        final list = data['invitations'] as List<dynamic>;
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (_) {
      try {
        final snapshot = await _firebase.firestore
            .collection('invitations')
            .where('organizationId', isEqualTo: organizationId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'invitationId': doc.id,
              'email': data['email'] ?? '',
              'role': data['role'] ?? 'member',
              'expiresAt': data['expiresAt']?.toString(),
            };
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetches paginated organization members securely via [getOrganizationMembers] Cloud Function,
  /// with automatic direct Firestore fallback if Cloud Function call is unavailable.
  Future<({List<Map<String, dynamic>> members, String? nextPageToken})>
      getOrganizationMembers({
    required String organizationId,
    int pageSize = 50,
    String? pageToken,
  }) async {
    try {
      final callable =
          _firebase.functions.httpsCallable('getOrganizationMembers');
      final response = await callable.call({
        'organizationId': organizationId.trim(),
        'pageSize': pageSize,
        if (pageToken != null && pageToken.isNotEmpty) 'pageToken': pageToken,
      });

      final data = response.data as Map<dynamic, dynamic>?;
      if (data != null &&
          data['status'] == 'success' &&
          data['members'] != null) {
        final rawList = data['members'] as List<dynamic>;
        final members =
            rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        return (
          members: members,
          nextPageToken: data['nextPageToken'] as String?,
        );
      }
    } catch (_) {
      try {
        final snapshot = await _firebase.firestore
            .collection(AppConstants.orgMembersCollection)
            .where('organizationId', isEqualTo: organizationId.trim())
            .get();

        if (snapshot.docs.isNotEmpty) {
          final members = snapshot.docs.map((doc) {
            final mData = doc.data();
            return <String, dynamic>{
              'id': doc.id,
              'userId': mData['userId'] ?? '',
              'displayName': mData['displayName'] ?? mData['email'] ?? 'Member',
              'email': mData['email'] ?? '',
              'role': mData['role'] ?? 'member',
              'status': mData['status'] ?? 'active',
              'departmentId': mData['departmentId'],
              'departmentName': mData['departmentName'],
            };
          }).toList();

          return (members: members, nextPageToken: null);
        }
      } catch (_) {}
    }
    return (members: <Map<String, dynamic>>[], nextPageToken: null);
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
      _orgCache.remove(organizationId);
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

  /// Streams a single organization document in real-time with local caching.
  Stream<Organization?> watchOrganization(String organizationId) {
    if (organizationId.isEmpty) return Stream.value(null);

    return _firebase.firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final org = Organization.fromFirestore(doc);
        _orgCache[organizationId] = org;
        return org;
      }
      _orgCache.remove(organizationId);
      return null;
    });
  }

  /// Fetches a single organization document once with high-performance cache.
  Future<Organization?> getOrganization(String organizationId) async {
    if (organizationId.isEmpty) return null;

    if (_orgCache.containsKey(organizationId)) {
      return _orgCache[organizationId];
    }

    final doc = await _firebase.firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .get();

    if (doc.exists) {
      final org = Organization.fromFirestore(doc);
      _orgCache[organizationId] = org;
      return org;
    }
    return null;
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
      throw Exception(
          'Organization logo exceeds 500 KB size limit (512,000 bytes).');
    }
    if (imageBytes.length < 3 ||
        imageBytes[0] != 0xFF ||
        imageBytes[1] != 0xD8 ||
        imageBytes[2] != 0xFF) {
      throw Exception('Organization logos must be JPEG images.');
    }

    // Upload to organization-scoped path: organizations/{orgId}/logo/logo.jpg
    final storageRef = _firebase.storage
        .ref()
        .child('organizations/$organizationId/logo/logo.jpg');
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
      _orgCache.remove(organizationId);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(mapFirebaseFunctionsError(e));
    }

    return downloadUrl;
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

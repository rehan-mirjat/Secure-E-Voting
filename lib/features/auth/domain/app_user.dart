import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the Global SecureVote Account.
/// This model specifically excludes any organization roles or permissions,
/// as those are tenant-specific and belong in [OrganizationMember].
class AppUser {
  const AppUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.phoneNumber,
    required this.emailVerified,
    required this.createdAt,
    this.lastLoginAt,
    required this.status,
  });

  final String userId;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String? phoneNumber;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String status;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      userId: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      emailVerified: data['emailVerified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      'emailVerified': emailVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastLoginAt != null) 'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
      'status': status,
    };
  }
}

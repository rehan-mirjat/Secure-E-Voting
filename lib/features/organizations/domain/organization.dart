import 'package:cloud_firestore/cloud_firestore.dart';
import 'organization_enums.dart';

/// Represents an independent tenant within the SecureVote ecosystem.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.email,
    this.website,
    this.logoUrl,
    this.brandColors = const {},
    required this.country,
    required this.city,
    required this.status,
    required this.ownerId,
    required this.createdAt,
    this.verifiedAt,
    this.suspendedAt,
  });

  final String id;
  final String name;
  final String type;
  final String description;
  final String email;
  final String? website;
  final String? logoUrl;
  final Map<String, String> brandColors;
  final String country;
  final String city;
  final OrganizationStatus status;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? suspendedAt;

  bool get isVerified => status == OrganizationStatus.verified || status == OrganizationStatus.active;
  bool get isActive => status == OrganizationStatus.active;
  bool get isSelectable => status == OrganizationStatus.pending || status == OrganizationStatus.verified || status == OrganizationStatus.active;

  factory Organization.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Organization(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? '',
      description: data['description'] as String? ?? '',
      email: data['email'] as String? ?? '',
      website: data['website'] as String?,
      logoUrl: data['logoUrl'] as String?,
      brandColors: (data['brandColors'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      country: data['country'] as String? ?? '',
      city: data['city'] as String? ?? '',
      status: OrganizationStatus.fromString(data['status'] as String? ?? 'pending'),
      ownerId: data['ownerId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      suspendedAt: (data['suspendedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'email': email,
      if (website != null) 'website': website,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (brandColors.isNotEmpty) 'brandColors': brandColors,
      'country': country,
      'city': city,
      'status': status.value,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      if (suspendedAt != null) 'suspendedAt': Timestamp.fromDate(suspendedAt!),
    };
  }
}

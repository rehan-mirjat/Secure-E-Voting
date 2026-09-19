import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String id;
  final String organizationId;
  final String votingEventId;
  final String label;
  final String description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  PollOption({
    required this.id,
    required this.organizationId,
    required this.votingEventId,
    required this.label,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PollOption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PollOption(
      id: data['id'] ?? doc.id,
      organizationId: data['organizationId'] ?? '',
      votingEventId: data['votingEventId'] ?? '',
      label: data['label'] ?? '',
      description: data['description'] ?? '',
      sortOrder: data['sortOrder'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

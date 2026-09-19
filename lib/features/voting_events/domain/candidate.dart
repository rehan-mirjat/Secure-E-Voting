import 'package:cloud_firestore/cloud_firestore.dart';

class Candidate {
  final String id;
  final String organizationId;
  final String votingEventId;
  final String name;
  final String party;
  final String bio;
  final String? photoUrl;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Candidate({
    required this.id,
    required this.organizationId,
    required this.votingEventId,
    required this.name,
    required this.party,
    required this.bio,
    this.photoUrl,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Candidate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Candidate(
      id: data['id'] ?? doc.id,
      organizationId: data['organizationId'] ?? '',
      votingEventId: data['votingEventId'] ?? '',
      name: data['name'] ?? '',
      party: data['party'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] as String?,
      photoPath: data['photoPath'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

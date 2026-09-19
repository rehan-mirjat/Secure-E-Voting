import 'package:cloud_firestore/cloud_firestore.dart';

enum VotingType { candidateElection, singleChoicePoll, yesNoPoll }
enum PrivacyMode { anonymous, identifiable }
enum EligibilityType { allMembers, selectedMembers, selectedDepartments }
enum VotingEventStatus { draft, scheduled, active, closed, cancelled, archived }

class VotingEvent {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final VotingType votingType;
  final PrivacyMode privacyMode;
  final int maxSelections;
  final EligibilityType eligibilityType;
  final List<String> eligibilityDepartmentIds;
  final List<String> eligibilityUserIds;
  final VotingEventStatus status;
  final DateTime startAt;
  final DateTime endAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final DateTime? archivedAt;
  final String? archivedBy;

  VotingEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.votingType,
    required this.privacyMode,
    required this.maxSelections,
    required this.eligibilityType,
    required this.eligibilityDepartmentIds,
    required this.eligibilityUserIds,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.closedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.archivedAt,
    this.archivedBy,
  });

  factory VotingEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VotingEvent(
      id: data['id'] ?? doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      votingType: _parseVotingType(data['votingType']),
      privacyMode: data['privacyMode'] == 'IDENTIFIABLE' ? PrivacyMode.identifiable : PrivacyMode.anonymous,
      maxSelections: data['maxSelections'] ?? 1,
      eligibilityType: _parseEligibilityType(data['eligibilityType']),
      eligibilityDepartmentIds: List<String>.from(data['eligibilityDepartmentIds'] ?? []),
      eligibilityUserIds: List<String>.from(data['eligibilityUserIds'] ?? []),
      status: _parseStatus(data['status']),
      startAt: (data['startAt'] as Timestamp).toDate(),
      endAt: (data['endAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      closedBy: data['closedBy'] as String?,
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelledBy: data['cancelledBy'] as String?,
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      archivedBy: data['archivedBy'] as String?,
    );
  }

  static VotingType _parseVotingType(String? val) {
    switch (val) {
      case 'SINGLE_CHOICE_POLL':
        return VotingType.singleChoicePoll;
      case 'YES_NO_POLL':
        return VotingType.yesNoPoll;
      case 'CANDIDATE_ELECTION':
      default:
        return VotingType.candidateElection;
    }
  }

  static EligibilityType _parseEligibilityType(String? val) {
    switch (val) {
      case 'SELECTED_MEMBERS':
        return EligibilityType.selectedMembers;
      case 'SELECTED_DEPARTMENTS':
        return EligibilityType.selectedDepartments;
      case 'ALL_MEMBERS':
      default:
        return EligibilityType.allMembers;
    }
  }

  static VotingEventStatus _parseStatus(String? val) {
    switch (val) {
      case 'SCHEDULED':
        return VotingEventStatus.scheduled;
      case 'ACTIVE':
        return VotingEventStatus.active;
      case 'CLOSED':
        return VotingEventStatus.closed;
      case 'CANCELLED':
        return VotingEventStatus.cancelled;
      case 'ARCHIVED':
        return VotingEventStatus.archived;
      case 'DRAFT':
      default:
        return VotingEventStatus.draft;
    }
  }
}

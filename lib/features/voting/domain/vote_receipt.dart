class VoteReceipt {
  final String receiptId;
  final String organizationId;
  final String votingEventId;
  final String userId;
  final DateTime votedAt;
  final String receiptHash;

  const VoteReceipt({
    required this.receiptId,
    required this.organizationId,
    required this.votingEventId,
    required this.userId,
    required this.votedAt,
    required this.receiptHash,
  });

  factory VoteReceipt.fromMap(Map<String, dynamic> map, String id) {
    return VoteReceipt(
      receiptId: id,
      organizationId: map['organizationId'] as String? ?? '',
      votingEventId: map['votingEventId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      votedAt: map['votedAt'] != null
          ? (map['votedAt'] as dynamic).toDate()
          : DateTime.now(),
      receiptHash: map['receiptHash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiptId': receiptId,
      'organizationId': organizationId,
      'votingEventId': votingEventId,
      'userId': userId,
      'votedAt': votedAt,
      'receiptHash': receiptHash,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoteReceipt &&
          runtimeType == other.runtimeType &&
          receiptId == other.receiptId &&
          organizationId == other.organizationId &&
          votingEventId == other.votingEventId &&
          userId == other.userId &&
          votedAt == other.votedAt &&
          receiptHash == other.receiptHash;

  @override
  int get hashCode => Object.hash(
        receiptId,
        organizationId,
        votingEventId,
        userId,
        votedAt,
        receiptHash,
      );
}

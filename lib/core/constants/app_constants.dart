class AppConstants {
  // Global User Collections
  static const String usersCollection = 'users';

  // Multi-Tenant Collections
  static const String organizationsCollection = 'organizations';
  static const String orgMembersCollection = 'organizationMembers';
  static const String orgInvitationsCollection = 'organizationInvitations';
  static const String joiningCodesCollection = 'joiningCodes';
  static const String departmentsCollection = 'departments';

  // Voting Event Collections
  static const String votingEventsCollection = 'votingEvents';
  static const String candidatesSubcollection = 'candidates';
  static const String pollOptionsSubcollection = 'options';

  // Core Voting Collections (Highly Restricted)
  static const String votesCollection = 'votes';
  static const String participationCollection = 'participation';
  static const String voteReceiptsCollection = 'voteReceipts';

  // Administrative & Security Collections
  static const String auditLogsCollection = 'auditLogs';
  static const String platformAuditLogsCollection = 'platformAuditLogs';
  static const String platformReportsCollection = 'platformReports';

  // Enums - Organization Roles
  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
  static const String roleMember = 'member';

  // Enums - Organization Status
  static const String orgStatusPending = 'pending';
  static const String orgStatusVerified = 'verified';
  static const String orgStatusActive = 'active';
  static const String orgStatusSuspended = 'suspended';
  static const String orgStatusRejected = 'rejected';

  // Enums - Membership Status
  static const String memberStatusPending = 'pending';
  static const String memberStatusActive = 'active';
  static const String memberStatusSuspended = 'suspended';
  static const String memberStatusRemoved = 'removed';

  // Enums - Voting Event Types
  static const String eventTypeElection = 'candidateElection';
  static const String eventTypeSingleChoice = 'singleChoice';
  static const String eventTypeYesNo = 'yesNo';

  // Enums - Privacy Modes
  static const String privacyAnonymous = 'anonymous';
  static const String privacyIdentifiable = 'identifiable';

  // Enums - Event Status
  static const String eventStatusDraft = 'draft';
  static const String eventStatusScheduled = 'scheduled';
  static const String eventStatusActive = 'active';
  static const String eventStatusClosed = 'closed';
  static const String eventStatusArchived = 'archived';
}

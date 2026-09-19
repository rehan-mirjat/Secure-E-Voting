enum OrganizationRole {
  owner('owner'),
  admin('admin'),
  member('member');

  final String value;
  const OrganizationRole(this.value);

  static OrganizationRole fromString(String value) {
    return OrganizationRole.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => OrganizationRole.member,
    );
  }
}

enum MembershipStatus {
  pending('pending'),
  active('active'),
  suspended('suspended'),
  removed('removed');

  final String value;
  const MembershipStatus(this.value);

  static MembershipStatus fromString(String value) {
    return MembershipStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => MembershipStatus.pending,
    );
  }
}

enum OrganizationStatus {
  pending('pending'),
  verified('verified'),
  active('active'),
  suspended('suspended'),
  rejected('rejected');

  final String value;
  const OrganizationStatus(this.value);

  static OrganizationStatus fromString(String value) {
    return OrganizationStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => OrganizationStatus.pending,
    );
  }
}

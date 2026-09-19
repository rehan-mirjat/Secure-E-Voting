import 'organization.dart';
import 'organization_member.dart';

/// Immutable tuple pairing the currently selected Organization and the user's
/// membership record for that organization.
class ActiveOrganizationContext {
  const ActiveOrganizationContext({
    required this.organization,
    required this.member,
  });

  final Organization organization;
  final OrganizationMember member;
}

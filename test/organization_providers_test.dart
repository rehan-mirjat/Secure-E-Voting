import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_enums.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';

void main() {
  group('Milestone 3 Step 1 Domain Models & Typed Enums Tests', () {
    test('OrganizationRole enum parses correctly', () {
      expect(OrganizationRole.fromString('owner'), equals(OrganizationRole.owner));
      expect(OrganizationRole.fromString('ADMIN'), equals(OrganizationRole.admin));
      expect(OrganizationRole.fromString('unknown'), equals(OrganizationRole.member));
    });

    test('MembershipStatus enum parses correctly', () {
      expect(MembershipStatus.fromString('active'), equals(MembershipStatus.active));
      expect(MembershipStatus.fromString('SUSPENDED'), equals(MembershipStatus.suspended));
      expect(MembershipStatus.fromString('unknown'), equals(MembershipStatus.pending));
    });

    test('OrganizationStatus enum parses correctly', () {
      expect(OrganizationStatus.fromString('verified'), equals(OrganizationStatus.verified));
      expect(OrganizationStatus.fromString('ACTIVE'), equals(OrganizationStatus.active));
      expect(OrganizationStatus.fromString('unknown'), equals(OrganizationStatus.pending));
    });

    test('OrganizationMember computed properties work as UI convenience helpers only', () {
      final ownerMember = OrganizationMember(
        membershipId: 'org1_user1',
        organizationId: 'org1',
        userId: 'user1',
        role: OrganizationRole.owner,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(ownerMember.isOwner, isTrue);
      expect(ownerMember.isAdmin, isTrue);
      expect(ownerMember.isActive, isTrue);

      final regularMember = OrganizationMember(
        membershipId: 'org1_user2',
        organizationId: 'org1',
        userId: 'user2',
        role: OrganizationRole.member,
        status: MembershipStatus.suspended,
        joinedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(regularMember.isOwner, isFalse);
      expect(regularMember.isAdmin, isFalse);
      expect(regularMember.isActive, isFalse);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/data/organization_repository.dart';
import 'package:secure_e_voting/features/organizations/domain/active_organization_context.dart';
import 'package:secure_e_voting/features/organizations/domain/organization.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_enums.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';
import 'package:secure_e_voting/features/organizations/presentation/membership_directory_screen.dart';
import 'package:secure_e_voting/features/organizations/presentation/member_profile_dialog.dart';
import 'package:secure_e_voting/features/organizations/presentation/providers/organization_providers.dart';

class MockOrganizationRepository implements OrganizationRepository {
  String? lastUpdatedRole;
  String? lastUpdatedStatus;
  String? lastRemovedUid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({List<Map<String, dynamic>> members, String? nextPageToken})> getOrganizationMembers({
    required String organizationId,
    int pageSize = 50,
    String? pageToken,
  }) async {
    return (
      members: [
        {
          'userId': 'user_owner',
          'displayName': 'Owner User',
          'email': 'owner@org.com',
          'role': 'owner',
          'status': 'active',
          'departmentName': 'Management',
        },
        {
          'userId': 'user_admin',
          'displayName': 'Admin User',
          'email': 'admin@org.com',
          'role': 'admin',
          'status': 'active',
          'departmentName': null,
        },
        {
          'userId': 'user_member',
          'displayName': 'Member User',
          'email': 'member@org.com',
          'role': 'member',
          'status': 'active',
          'departmentName': 'Computer Science',
        },
      ],
      nextPageToken: null,
    );
  }

  @override
  Future<void> updateMemberRole({
    required String organizationId,
    required String targetUid,
    required String newRole,
  }) async {
    lastUpdatedRole = newRole;
  }

  @override
  Future<void> updateMemberStatus({
    required String organizationId,
    required String targetUid,
    required String newStatus,
  }) async {
    lastUpdatedStatus = newStatus;
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String targetUid,
  }) async {
    lastRemovedUid = targetUid;
  }
}

ActiveOrgState _createMockState({required OrganizationRole role, required String orgId}) {
  return ActiveOrgState(
    context: ActiveOrganizationContext(
      organization: Organization(
        id: orgId,
        name: 'Directory Test Org',
        type: 'academic',
        description: 'Testing',
        email: 'test@org.com',
        country: 'PK',
        city: 'Khi',
        status: OrganizationStatus.verified,
        ownerId: 'user_owner',
        createdAt: DateTime.now(),
      ),
      member: OrganizationMember(
        membershipId: '${orgId}_user_1',
        organizationId: orgId,
        userId: 'user_1',
        role: role,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
    selectionState: ActiveOrgSelectionState.restored,
    availableMemberships: [],
  );
}

void main() {
  group('MembershipDirectoryScreen & MemberProfileDialog Widget Tests', () {
    testWidgets('MembershipDirectoryScreen renders list and search filtering works', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.owner, orgId: 'org_123'))),
        ],
        child: const MaterialApp(home: MembershipDirectoryScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Member Directory'), findsOneWidget);
      expect(find.text('Owner User'), findsOneWidget);
      expect(find.text('Admin User'), findsOneWidget);
      expect(find.text('Member User'), findsOneWidget);

      // Search Filter Test
      await tester.enterText(find.byType(TextField), 'member@org.com');
      await tester.pump();

      expect(find.text('Member User'), findsOneWidget);
      expect(find.text('Owner User'), findsNothing);
      expect(find.text('Admin User'), findsNothing);
    });

    testWidgets('MemberProfileDialog shows Promote button for Owner viewing Member', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          organizationRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MemberProfileDialog(
              organizationId: 'org_123',
              callerRole: OrganizationRole.owner,
              memberData: const {
                'userId': 'user_member',
                'displayName': 'Member User',
                'email': 'member@org.com',
                'role': 'member',
                'status': 'active',
                'departmentName': 'Computer Science',
              },
              onChanged: () {},
            ),
          ),
        ),
      ));

      expect(find.text('Promote to Admin'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.text('Promote to Admin'));
      await tester.pumpAndSettle();

      expect(mockRepo.lastUpdatedRole, equals('admin'));
    });

    testWidgets('MemberProfileDialog hides Promote/Demote buttons for Admin viewing Member', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          organizationRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MemberProfileDialog(
              organizationId: 'org_123',
              callerRole: OrganizationRole.admin,
              memberData: const {
                'userId': 'user_member',
                'displayName': 'Member User',
                'email': 'member@org.com',
                'role': 'member',
                'status': 'active',
                'departmentName': 'Computer Science',
              },
              onChanged: () {},
            ),
          ),
        ),
      ));

      expect(find.text('Promote to Admin'), findsNothing); // Admins CANNOT promote members
      expect(find.text('Deactivate'), findsOneWidget); // Admins CAN deactivate members
      expect(find.text('Remove'), findsOneWidget); // Admins CAN remove members
    });
  });
}

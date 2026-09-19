import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/departments/data/department_repository.dart';
import 'package:secure_e_voting/features/departments/domain/department.dart';
import 'package:secure_e_voting/features/departments/presentation/departments_screen.dart';
import 'package:secure_e_voting/features/organizations/domain/active_organization_context.dart';
import 'package:secure_e_voting/features/organizations/domain/organization.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_enums.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';
import 'package:secure_e_voting/features/organizations/presentation/providers/organization_providers.dart';

class MockDepartmentRepository implements DepartmentRepository {
  bool failDelete = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<Department>> watchDepartments(String organizationId) {
    if (organizationId == 'org_empty') return Stream.value([]);
    return Stream.value([
      const Department(
        id: 'dept_1',
        organizationId: 'org_123',
        name: 'Computer Science',
        description: 'CS Dept',
        createdBy: 'user_1',
      )
    ]);
  }

  @override
  Future<void> deleteDepartment(String departmentId) async {
    if (failDelete) throw Exception('Permission denied.');
  }
}

ActiveOrgState _createMockState({required OrganizationRole role, required String orgId}) {
  return ActiveOrgState(
    context: ActiveOrganizationContext(
      organization: Organization(
        id: orgId,
        name: 'Test Org',
        type: 'academic',
        description: 'Testing',
        email: 'test@org.com',
        country: 'PK',
        city: 'Khi',
        status: OrganizationStatus.verified,
        ownerId: 'owner_1',
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
  group('DepartmentsScreen Comprehensive UI Tests', () {
    testWidgets('Renders empty state for regular members', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          departmentRepositoryProvider.overrideWithValue(MockDepartmentRepository()),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.member, orgId: 'org_empty'))),
        ],
        child: const MaterialApp(home: DepartmentsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Departments Found'), findsOneWidget);
      expect(find.text('This organization has no departments.'), findsOneWidget); // Member text
      expect(find.text('New Department'), findsNothing); // FAB hidden for members
    });

    testWidgets('Renders empty state for Owner/Admin with CTA', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          departmentRepositoryProvider.overrideWithValue(MockDepartmentRepository()),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.admin, orgId: 'org_empty'))),
        ],
        child: const MaterialApp(home: DepartmentsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Departments Found'), findsOneWidget);
      expect(find.text('Create departments to organize members and restrict voting eligibility.'), findsOneWidget); // Admin text
      expect(find.text('New Department'), findsOneWidget); // FAB shown for admins
    });

    testWidgets('Populated list renders properly and Member sees NO actions', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          departmentRepositoryProvider.overrideWithValue(MockDepartmentRepository()),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.member, orgId: 'org_123'))),
        ],
        child: const MaterialApp(home: DepartmentsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('CS Dept'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing); // No FAB
      expect(find.byType(PopupMenuButton<String>), findsNothing); // No Edit/Delete trailing menu
    });

    testWidgets('Owner/Admin sees actions and destructive delete confirmation text is correct', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          departmentRepositoryProvider.overrideWithValue(MockDepartmentRepository()),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.owner, orgId: 'org_123'))),
        ],
        child: const MaterialApp(home: DepartmentsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Computer Science'), findsOneWidget);
      expect(find.text('New Department'), findsOneWidget); // FAB is present
      
      final menuFinder = find.byType(PopupMenuButton<String>);
      expect(menuFinder, findsOneWidget); // Trailing menu is present

      // Open PopupMenu
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify the dialog text specifically addresses the scalable "stale reference" policy
      expect(find.text('Delete Department'), findsOneWidget);
      expect(find.textContaining('This permanently deletes the department. Existing member records may retain a reference to the deleted department, but the deleted department will no longer be valid for assignment or voting eligibility.'), findsOneWidget);

      // Verify Delete Permanently button
      expect(find.text('Delete Permanently'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Delete failure shows safe error SnackBar', (WidgetTester tester) async {
      final mockRepo = MockDepartmentRepository()..failDelete = true;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          departmentRepositoryProvider.overrideWithValue(mockRepo),
          activeOrganizationContextProvider.overrideWith((ref) => Stream.value(_createMockState(role: OrganizationRole.admin, orgId: 'org_123'))),
        ],
        child: const MaterialApp(home: DepartmentsScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm Delete
      await tester.tap(find.text('Delete Permanently'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to delete: Permission denied.'), findsOneWidget);
    });
  });
}

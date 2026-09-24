import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/data/organization_repository.dart';
import 'package:secure_e_voting/features/organizations/presentation/invite_member_dialog.dart';
import 'package:secure_e_voting/features/organizations/presentation/pending_invitations_widget.dart';

class MockOrganizationRepository implements OrganizationRepository {
  String? lastInvitedEmail;
  String? lastInvitedRole;
  String? lastRevokedInvitationId;
  bool shouldFail = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({String email, String invitationId, String rawToken})> inviteMember({
    required String organizationId,
    required String email,
    required String role,
    int expiresInHours = 168,
  }) async {
    if (shouldFail) {
      throw Exception('You do not have permission to perform this action.');
    }
    lastInvitedEmail = email;
    lastInvitedRole = role;
    return (
      rawToken: 'mock_raw_token_32_chars_1234567890',
      invitationId: 'inv_123',
      email: email,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingInvitations(String organizationId) async {
    if (shouldFail) {
      throw Exception('Access denied');
    }
    return [
      {
        'invitationId': 'inv_123',
        'email': 'voter@organization.com',
        'role': 'member',
        'status': 'pending',
      },
      {
        'invitationId': 'inv_456',
        'email': 'admin@organization.com',
        'role': 'admin',
        'status': 'pending',
      },
    ];
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    if (shouldFail) {
      throw Exception('You do not have permission to perform this action.');
    }
    lastRevokedInvitationId = invitationId;
  }
}

void main() {
  group('InviteMemberDialog Comprehensive Hardening Tests', () {
    testWidgets('Rejects empty and malformed email inputs', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: InviteMemberDialog(organizationId: 'org_1', organizationName: 'Org 1', isOwner: true))),
      ));

      // Empty email
      await tester.tap(find.text('Send Invitation'));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);

      // Malformed email
      await tester.enterText(find.widgetWithText(TextFormField, 'Recipient Email Address *'), 'not-an-email');
      await tester.tap(find.text('Send Invitation'));
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('Owner can select Admin role and it is passed to repository', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: InviteMemberDialog(organizationId: 'org_1', organizationName: 'Org 1', isOwner: true))),
      ));

      await tester.enterText(find.widgetWithText(TextFormField, 'Recipient Email Address *'), 'admin@org.com');
      
      // Select Admin Role
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(mockRepo.lastInvitedEmail, equals('admin@org.com'));
      expect(mockRepo.lastInvitedRole, equals('admin'));
    });

    testWidgets('Non-Owner (Admin) CANNOT select Admin role', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: InviteMemberDialog(organizationId: 'org_1', organizationName: 'Org 1', isOwner: false))),
      ));

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Member'), findsWidgets);
    });

    testWidgets('Successful invitation displays returned raw token and clipboard copy works', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: InviteMemberDialog(organizationId: 'org_1', organizationName: 'Org 1', isOwner: true))),
      ));

      await tester.enterText(find.widgetWithText(TextFormField, 'Recipient Email Address *'), 'voter@org.com');
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('mock_raw_token_32_chars_1234567890'), findsOneWidget);

      // Verify Copy to Clipboard
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
      expect(find.text('Invitation token copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Displays safe fallback error when backend fails', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository()..shouldFail = true;
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: InviteMemberDialog(organizationId: 'org_1', organizationName: 'Org 1', isOwner: true))),
      ));

      await tester.enterText(find.widgetWithText(TextFormField, 'Recipient Email Address *'), 'voter@org.com');
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission to perform this action.'), findsOneWidget);
    });
  });

  group('PendingInvitationsWidget Comprehensive Hardening Tests', () {
    testWidgets('Owner can revoke both Member and Admin invitations', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: PendingInvitationsWidget(organizationId: 'org_1', isOwner: true))),
      ));
      await tester.pumpAndSettle();

      final revokeButtons = find.text('Revoke');
      expect(revokeButtons, findsNWidgets(2)); // Both should be revokable by Owner

      await tester.tap(revokeButtons.last); // Revoke the Admin one
      await tester.pumpAndSettle();

      // Verifies the opaque invitationId is used, not tokenHash
      expect(mockRepo.lastRevokedInvitationId, equals('inv_456'));
    });

    testWidgets('Admin CANNOT revoke Admin-level invitation (Locked State)', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: PendingInvitationsWidget(organizationId: 'org_1', isOwner: false))),
      ));
      await tester.pumpAndSettle();

      final revokeButtons = find.text('Revoke');
      expect(revokeButtons, findsOneWidget); // Only Member is revokable by Admin

      final lockIcon = find.byIcon(Icons.lock_outline);
      expect(lockIcon, findsOneWidget); // Admin invitation is locked
    });

    testWidgets('Revocation failure displays safe error message', (WidgetTester tester) async {
      final mockRepo = MockOrganizationRepository()..shouldFail = false; // Initially succeed loading list
      await tester.pumpWidget(ProviderScope(
        overrides: [organizationRepositoryProvider.overrideWithValue(mockRepo)],
        child: const MaterialApp(home: Scaffold(body: PendingInvitationsWidget(organizationId: 'org_1', isOwner: true))),
      ));
      await tester.pumpAndSettle();

      final revokeButtons = find.text('Revoke');
      expect(revokeButtons, findsWidgets);

      // Tell mock to fail on revoke
      mockRepo.shouldFail = true;

      await tester.tap(revokeButtons.first);
      await tester.pump();

      expect(find.text('Failed to revoke invitation: You do not have permission to perform this action.'), findsOneWidget);
    });
  });
}

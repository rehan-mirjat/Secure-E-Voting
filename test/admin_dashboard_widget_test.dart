import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/voting_events/domain/voting_event.dart';
import 'package:secure_e_voting/features/voting_events/presentation/dashboard/admin_event_dashboard_screen.dart';
import 'package:secure_e_voting/features/organizations/presentation/providers/organization_providers.dart';
import 'package:secure_e_voting/features/organizations/domain/active_organization_context.dart';
import 'package:secure_e_voting/features/organizations/domain/organization.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_enums.dart';
import 'package:secure_e_voting/features/voting_events/data/voting_event_repository.dart';
import 'package:secure_e_voting/features/voting_events/presentation/providers/event_lifecycle_provider.dart';

// Dummy classes to satisfy ActiveOrgState and dependencies
class FakeVotingEventRepository implements VotingEventRepository {
  final List<VotingEvent> events;
  FakeVotingEventRepository(this.events);
  
  @override
  Stream<List<VotingEvent>> watchOrganizationVotingEvents(String organizationId) {
    return Stream.value(events);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createDashboardWidget({
    required OrganizationRole role,
    required List<VotingEvent> events,
    EventLifecycleState? mockLifecycleState,
  }) {
    final org = Organization(id: 'org_1', name: 'Test Org', type: 'academic', description: '', status: OrganizationStatus.verified, country: 'Test', city: 'Test', email: 'test@test.com', ownerId: 'test', createdAt: DateTime.now());
    final member = OrganizationMember(membershipId: 'mem_1', organizationId: 'org_1', userId: 'user_1', role: role, status: MembershipStatus.active, joinedAt: DateTime.now(), updatedAt: DateTime.now());
    
    final fakeContext = ActiveOrgState(
      context: ActiveOrganizationContext(organization: org, member: member),
      selectionState: ActiveOrgSelectionState.restored,
      availableMemberships: [member],
    );

    return ProviderScope(
      overrides: [
        activeOrganizationContextProvider.overrideWith((ref) => Stream.value(fakeContext)),
        votingEventRepositoryProvider.overrideWithValue(FakeVotingEventRepository(events)),
        if (mockLifecycleState != null)
           eventLifecycleProvider.overrideWith((ref) => EventLifecycleNotifier(ref.watch(votingEventRepositoryProvider))..state = mockLifecycleState)
      ],
      child: Consumer(builder: (context, ref, child) {
        return const MaterialApp(
          home: AdminEventDashboardScreen(),
        );
      }),
    );
  }

  group('Milestone 4 Step 7 - Dashboard Screen UI Assertions', () {
    testWidgets('14.1 Admin can access Event Builder route', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(role: OrganizationRole.admin, events: []));
      await tester.pumpAndSettle();
      expect(find.text('Event Management'), findsOneWidget);
    });

    testWidgets('14.5 Empty state UI displays correctly when organization has 0 events', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(role: OrganizationRole.admin, events: []));
      await tester.pumpAndSettle();

      expect(find.text('No voting events found.'), findsOneWidget);
      expect(find.text('Create your first Voting Event'), findsOneWidget);
    });

    testWidgets('14.17 Asynchronous loading overlays appear during lifecycle callable execution', (WidgetTester tester) async {
      final mockState = EventLifecycleState(isLoading: true);
      await tester.pumpWidget(createDashboardWidget(role: OrganizationRole.admin, events: [], mockLifecycleState: mockState));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('14.18 Backend failed-precondition maps to safe UI error', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(role: OrganizationRole.admin, events: []));
      await tester.pump();
      
      final element = tester.element(find.byType(AdminEventDashboardScreen));
      final container = ProviderScope.containerOf(element);
      container.read(eventLifecycleProvider.notifier).state = EventLifecycleState(error: 'failed-precondition: The event status has changed.');
      
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('failed-precondition'), findsOneWidget);
    });

    testWidgets('14.19 Backend permission-denied maps to safe UI error', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(role: OrganizationRole.admin, events: []));
      await tester.pump();
      
      final element = tester.element(find.byType(AdminEventDashboardScreen));
      final container = ProviderScope.containerOf(element);
      container.read(eventLifecycleProvider.notifier).state = EventLifecycleState(error: 'permission-denied: You do not have permission for this action.');
      
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsOneWidget);
    });
  });
}

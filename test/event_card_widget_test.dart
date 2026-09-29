import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:secure_e_voting/features/voting_events/domain/voting_event.dart';
import 'package:secure_e_voting/features/voting_events/presentation/dashboard/event_card.dart';

void main() {
  Widget createWidgetUnderTest(VotingEvent event) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: EventCard(event: event),
          ),
        ),
        GoRoute(
          path: '/admin/events/:id/monitor',
          builder: (context, state) => const Scaffold(body: Text('coming in Milestone 6')),
        ),
        GoRoute(
          path: '/elections/:id/results',
          builder: (context, state) => const Scaffold(body: Text('coming in Milestone 6')),
        ),
        GoRoute(
          path: '/admin/events/:id/edit',
          builder: (context, state) => const Scaffold(body: Text('Edit')),
        ),
        GoRoute(
          path: '/admin/events/:id/choices',
          builder: (context, state) => const Scaffold(body: Text('Choices')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  VotingEvent createTestEvent({required VotingEventStatus status}) {
    return VotingEvent(
      id: 'test_event_1',
      organizationId: 'org_1',
      title: 'Test Event Title',
      description: 'Test Event Description',
      votingType: VotingType.candidateElection,
      privacyMode: PrivacyMode.anonymous,
      maxSelections: 1,
      eligibilityType: EligibilityType.allMembers,
      eligibilityDepartmentIds: [],
      eligibilityUserIds: [],
      status: status,
      startAt: DateTime.now().add(const Duration(days: 1)),
      endAt: DateTime.now().add(const Duration(days: 2)),
      createdBy: 'admin_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('Milestone 4 Step 7 - EventCard UI Assertions', () {
    testWidgets('14.6 DRAFT event exposes Edit Config, Manage Choices, Publish, and Delete', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.draft);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('Edit Config'), findsOneWidget);
      expect(find.text('Manage Choices'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('14.7 SCHEDULED event exposes View Details and Cancel Event', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.scheduled);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Cancel Event'), findsOneWidget);
    });

    testWidgets('14.8 ACTIVE event exposes Monitor Turnout and Close Early', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.active);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('Monitor Turnout'), findsOneWidget);
      expect(find.text('Close Early'), findsOneWidget);
    });

    testWidgets('14.9 CLOSED event exposes View Results', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.closed);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('View Results'), findsOneWidget);
    });

    testWidgets('14.10 CANCELLED event exposes View Details', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.cancelled);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('14.11 Monitor (Turnout) shortcut successfully routes to stub', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.active);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Monitor Turnout'));
      await tester.pumpAndSettle();

      expect(find.text('coming in Milestone 6'), findsOneWidget);
    });

    testWidgets('14.12 View Results shortcut successfully routes to stub', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.closed);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('View Results'));
      await tester.pumpAndSettle();

      expect(find.text('coming in Milestone 6'), findsOneWidget);
    });

    testWidgets('14.13 Clicking Delete on a DRAFT requires explicit confirmation', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.draft);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Draft Event?'), findsOneWidget);
      expect(find.text('Are you sure you want to permanently delete "Test Event Title"? This cannot be undone.'), findsOneWidget);
    });
  });
}

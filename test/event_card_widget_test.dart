import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/voting_events/domain/voting_event.dart';
import 'package:secure_e_voting/features/voting_events/presentation/dashboard/event_card.dart';

void main() {
  Widget createWidgetUnderTest(VotingEvent event) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: EventCard(event: event),
        ),
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

      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Manage Choices'), findsOneWidget);
      expect(find.text('Edit Config'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
    });

    testWidgets('14.7 SCHEDULED event exposes View Details and Cancel', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.scheduled);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(find.text('Cancel Event'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      
      expect(find.text('Edit Config'), findsNothing);
      expect(find.text('Manage Choices'), findsNothing);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('14.8 ACTIVE events expose Monitor and Close Early, hide Cancel/Edit', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.active);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Close Early'), findsOneWidget);
      expect(find.text('Monitor Turnout'), findsOneWidget);

      expect(find.text('Edit Config'), findsNothing);
      expect(find.text('Cancel Event'), findsNothing);
    });

    testWidgets('14.9 CLOSED event exposes View Results only', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.closed);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('CLOSED'), findsOneWidget);
      expect(find.text('View Results'), findsOneWidget);
      
      expect(find.text('Edit Config'), findsNothing);
      expect(find.text('Cancel Event'), findsNothing);
      expect(find.text('Close Early'), findsNothing);
    });

    testWidgets('14.10 CANCELLED event exposes strictly read-only details', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.cancelled);
      await tester.pumpWidget(createWidgetUnderTest(event));

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      
      expect(find.text('Edit Config'), findsNothing);
      expect(find.text('Cancel Event'), findsNothing);
    });

    testWidgets('14.11 Monitor (Turnout) shortcut successfully routes to stub', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.active);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Monitor Turnout'));
      await tester.pumpAndSettle();

      expect(find.textContaining('coming in Milestone 6'), findsOneWidget);
    });

    testWidgets('14.12 View Results shortcut successfully routes to stub', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.closed);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('View Results'));
      await tester.pumpAndSettle();

      expect(find.textContaining('coming in Milestone 6'), findsOneWidget);
    });

    testWidgets('14.13 Clicking Delete on a DRAFT requires explicit confirmation', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.draft);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Draft Event?'), findsOneWidget);
      
      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Draft Event?'), findsNothing);
    });

    testWidgets('14.15 Clicking Cancel on a SCHEDULED event requires confirmation', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.scheduled);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Cancel Event'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Scheduled Event?'), findsOneWidget);
    });

    testWidgets('14.16 Clicking Close Early on an ACTIVE event requires confirmation', (WidgetTester tester) async {
      final event = createTestEvent(status: VotingEventStatus.active);
      await tester.pumpWidget(createWidgetUnderTest(event));

      await tester.tap(find.text('Close Early'));
      await tester.pumpAndSettle();

      expect(find.text('Close Event Early?'), findsOneWidget);
    });
  });
}

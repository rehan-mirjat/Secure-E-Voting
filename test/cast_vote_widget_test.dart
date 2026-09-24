import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secure_e_voting/features/voting/data/voting_repository.dart';
import 'package:secure_e_voting/features/voting/domain/vote_receipt.dart';
import 'package:secure_e_voting/features/voting/presentation/cast_vote_screen.dart';
import 'package:secure_e_voting/features/voting_events/data/candidate_repository.dart';
import 'package:secure_e_voting/features/voting_events/data/poll_option_repository.dart';
import 'package:secure_e_voting/features/voting_events/data/voting_event_repository.dart';
import 'package:secure_e_voting/features/voting_events/domain/candidate.dart';
import 'package:secure_e_voting/features/voting_events/domain/poll_option.dart';
import 'package:secure_e_voting/features/voting_events/domain/voting_event.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  final String uid = 'voter1';
}

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => MockUser();

  @override
  Stream<User?> get authStateChanges => Stream.value(MockUser());

  @override
  bool get isEmailVerified => true;
}

class MockVotingEventRepository implements VotingEventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<VotingEvent?> watchVotingEvent(String eventId) {
    return Stream.value(VotingEvent(
      id: eventId,
      organizationId: 'org1',
      title: 'Annual General Election',
      description: 'Vote for your preferred leader',
      votingType: VotingType.candidateElection,
      privacyMode: PrivacyMode.anonymous,
      maxSelections: 1,
      eligibilityType: EligibilityType.allMembers,
      eligibilityDepartmentIds: const [],
      eligibilityUserIds: const [],
      status: VotingEventStatus.active,
      startAt: DateTime.now().subtract(const Duration(hours: 1)),
      endAt: DateTime.now().add(const Duration(hours: 24)),
      createdBy: 'admin1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }
}

class MockCandidateRepository implements CandidateRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<Candidate>> watchEventCandidates(String eventId) {
    return Stream.value([
      Candidate(
        id: 'cand1',
        organizationId: 'org1',
        votingEventId: eventId,
        name: 'Alice Johnson',
        party: 'Progressive Party',
        bio: 'Experienced community leader',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Candidate(
        id: 'cand2',
        organizationId: 'org1',
        votingEventId: eventId,
        name: 'Bob Smith',
        party: 'Reform Alliance',
        bio: 'Technology & growth advocate',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
  }
}

class MockPollOptionRepository implements PollOptionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<PollOption>> watchEventPollOptions(String eventId) {
    return Stream.value([]);
  }
}

class MockVotingRepository implements VotingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<bool> watchUserParticipation({
    required String organizationId,
    required String eventId,
    required String userId,
  }) {
    return Stream.value(false); // Has not voted
  }

  @override
  Future<VoteReceipt> castVote({
    required String organizationId,
    required String eventId,
    String? candidateId,
    String? pollOptionId,
  }) async {
    return VoteReceipt(
      receiptId: 'receipt_12345',
      organizationId: organizationId,
      votingEventId: eventId,
      userId: 'voter1',
      votedAt: DateTime.now(),
      receiptHash: 'a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890a1b2c3d4e5f67890',
    );
  }
}

void main() {
  group('CastVoteScreen Widget Tests', () {
    testWidgets('Renders ballot and candidates correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(MockAuthService()),
            votingEventRepositoryProvider.overrideWithValue(MockVotingEventRepository()),
            candidateRepositoryProvider.overrideWithValue(MockCandidateRepository()),
            pollOptionRepositoryProvider.overrideWithValue(MockPollOptionRepository()),
            votingRepositoryProvider.overrideWithValue(MockVotingRepository()),
          ],
          child: const MaterialApp(
            home: CastVoteScreen(eventId: 'event1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Annual General Election'), findsOneWidget);
      expect(find.text('OFFICIAL BALLOT'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Progressive Party'), findsOneWidget);
    });

    testWidgets('Selecting candidate and tapping submit triggers confirmation dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(MockAuthService()),
            votingEventRepositoryProvider.overrideWithValue(MockVotingEventRepository()),
            candidateRepositoryProvider.overrideWithValue(MockCandidateRepository()),
            pollOptionRepositoryProvider.overrideWithValue(MockPollOptionRepository()),
            votingRepositoryProvider.overrideWithValue(MockVotingRepository()),
          ],
          child: const MaterialApp(
            home: CastVoteScreen(eventId: 'event1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Alice Johnson
      await tester.tap(find.text('Alice Johnson'));
      await tester.pumpAndSettle();

      // Tap Submit Official Ballot
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Official Ballot');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Confirm Ballot Submission'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsNWidgets(2)); // Card + Dialog summary
      expect(find.text('Confirm & Cast Ballot'), findsOneWidget);
    });
  });
}

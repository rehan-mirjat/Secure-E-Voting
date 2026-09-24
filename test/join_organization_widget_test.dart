import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/data/organization_repository.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';
import 'package:secure_e_voting/features/organizations/presentation/join_organization_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  final String uid = 'test_user';
}

class MockOrganizationRepository implements OrganizationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({String organizationId, String organizationName})> joinOrganizationWithCode(String rawCode) async {
    if (rawCode.contains('ERROR')) {
      throw Exception('Invalid joining code.');
    }
    if (rawCode.contains('EXHAUSTED')) {
      throw Exception('Too many failed attempts. Please wait 5 minutes before trying again.');
    }
    return (organizationId: 'org_joined_123', organizationName: 'Apex University');
  }

  @override
  Stream<List<OrganizationMember>> watchUserMemberships(String userId) {
    return Stream.value([]);
  }
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

void main() {
  group('JoinOrganizationScreen Widget Tests', () {
    testWidgets('Renders UI and validates empty input', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: JoinOrganizationScreen(),
          ),
        ),
      );

      expect(find.text('Join an Organization'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Joining Code *'), findsOneWidget);

      final submitButton = find.widgetWithText(ElevatedButton, 'Join Organization');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Joining Code is required'), findsOneWidget);
    });

    testWidgets('Displays rate-limit error message when backend fails', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: JoinOrganizationScreen(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Joining Code *'), 'EXHAUSTED-CODE');

      final submitButton = find.widgetWithText(ElevatedButton, 'Join Organization');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Too many failed attempts. Please wait 5 minutes before trying again.'), findsOneWidget);
    });

    testWidgets('Successful join invokes onJoined callback', (WidgetTester tester) async {
      String? joinedOrgId;
      String? joinedOrgName;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: MaterialApp(
            home: JoinOrganizationScreen(
              onJoined: (id, name) {
                joinedOrgId = id;
                joinedOrgName = name;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Joining Code *'), 'JOIN-7K9P-X4M2');

      final submitButton = find.widgetWithText(ElevatedButton, 'Join Organization');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(joinedOrgId, equals('org_joined_123'));
      expect(joinedOrgName, equals('Apex University'));
    });
  });
}

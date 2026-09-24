import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/data/organization_repository.dart';
import 'package:secure_e_voting/features/organizations/domain/organization.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_enums.dart';
import 'package:secure_e_voting/features/organizations/domain/organization_member.dart';
import 'package:secure_e_voting/features/organizations/presentation/organization_context_switcher.dart';
import 'package:secure_e_voting/features/organizations/presentation/organization_list_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockUser extends Fake implements User {
  @override
  final String uid = 'user1';
}

class MockOrganizationRepository implements OrganizationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<OrganizationMember>> watchUserMemberships(String userId) {
    return Stream.value([
      OrganizationMember(
        membershipId: 'org1_user1',
        organizationId: 'org1',
        userId: userId,
        role: OrganizationRole.owner,
        status: MembershipStatus.active,
        joinedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<Organization?> getOrganization(String organizationId) async {
    return Organization(
      id: organizationId,
      name: 'Apex Academic Institute',
      type: 'academic',
      description: 'Research university',
      email: 'contact@apex.edu.pk',
      country: 'Pakistan',
      city: 'Karachi',
      status: OrganizationStatus.active,
      ownerId: 'user1',
      createdAt: DateTime.now(),
    );
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
  group('OrganizationListScreen & Switcher Widget Tests', () {
    testWidgets('OrganizationListScreen renders joined organizations with role badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: OrganizationListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Active Organizations'), findsOneWidget);
      expect(find.text('Apex Academic Institute'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('Create New Organization'), findsOneWidget);
    });

    testWidgets('OrganizationContextSwitcher renders active context widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: OrganizationContextSwitcher(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apex Academic Institute'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
    });
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/organizations/data/organization_repository.dart';
import 'package:secure_e_voting/features/organizations/presentation/create_organization_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockOrganizationRepository implements OrganizationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String> createOrganization({
    required String name,
    required String type,
    required String description,
    required String email,
    required String country,
    required String city,
    String? website,
    String? logoUrl,
  }) async {
    if (name.contains('Error')) {
      throw Exception('Unable to create organization. Please try again.');
    }
    return 'mock_org_id_123';
  }
}

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  bool get isEmailVerified => false;
}

void main() {
  group('CreateOrganizationScreen Comprehensive Widget Tests', () {
    testWidgets('Validates empty required fields on submit', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: CreateOrganizationScreen(),
          ),
        ),
      );

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Organization Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Country is required'), findsOneWidget);
      expect(find.text('City is required'), findsOneWidget);
    });

    testWidgets('Validates short name and invalid email format', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: CreateOrganizationScreen(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Organization Name *'), 'Ab');
      await tester.enterText(find.widgetWithText(TextFormField, 'Official Contact Email *'), 'not_an_email');

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Name must be at least 3 characters'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('Validates name > 100 chars and description > 500 chars', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: CreateOrganizationScreen(),
          ),
        ),
      );

      final longName = 'A' * 105;
      final longDesc = 'D' * 505;

      await tester.enterText(find.widgetWithText(TextFormField, 'Organization Name *'), longName);
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), longDesc);

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Name cannot exceed 100 characters'), findsOneWidget);
      expect(find.text('Description cannot exceed 500 characters'), findsOneWidget);
    });

    testWidgets('Validates non-HTTPS website URL', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: CreateOrganizationScreen(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Website URL (Optional)'), 'http://insecure.com');

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Website must start with https://'), findsOneWidget);
    });

    testWidgets('Displays safe user-facing error message when backend fails', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: const MaterialApp(
            home: CreateOrganizationScreen(),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Organization Name *'), 'Error Apex Org');
      await tester.enterText(find.widgetWithText(TextFormField, 'Official Contact Email *'), 'contact@apex.edu.pk');
      await tester.enterText(find.widgetWithText(TextFormField, 'Country *'), 'Pakistan');
      await tester.enterText(find.widgetWithText(TextFormField, 'City *'), 'Karachi');

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to create organization'), findsOneWidget);
    });

    testWidgets('Valid form submission triggers onOrganizationCreated callback', (WidgetTester tester) async {
      String? createdOrgId;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            organizationRepositoryProvider.overrideWithValue(MockOrganizationRepository()),
            authServiceProvider.overrideWithValue(MockAuthService()),
          ],
          child: MaterialApp(
            home: CreateOrganizationScreen(
              onOrganizationCreated: (id) => createdOrgId = id,
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Organization Name *'), 'Apex University');
      await tester.enterText(find.widgetWithText(TextFormField, 'Official Contact Email *'), 'contact@apex.edu.pk');
      await tester.enterText(find.widgetWithText(TextFormField, 'Country *'), 'Pakistan');
      await tester.enterText(find.widgetWithText(TextFormField, 'City *'), 'Karachi');

      final submitButton = find.text('Submit Organization Registration');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(createdOrgId, equals('mock_org_id_123'));
    });
  });
}

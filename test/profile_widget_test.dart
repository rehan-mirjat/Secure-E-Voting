import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/data/user_repository.dart';
import 'package:secure_e_voting/features/auth/domain/app_user.dart';
import 'package:secure_e_voting/features/auth/presentation/profile_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockUserInfo extends Fake implements UserInfo {
  @override
  final String providerId = 'password';
}

class MockUser extends Fake implements User {
  @override
  final bool emailVerified = true;
  @override
  final String? email = 'rehan@securevote.com';
  @override
  final List<UserInfo> providerData = [MockUserInfo()];
}

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => MockUser();

  @override
  bool get isEmailVerified => true;
}

class MockUserRepository implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<AppUser?> watchUserProfile(String uid) {
    return Stream.value(
      AppUser(
        userId: uid,
        email: 'rehan@securevote.com',
        displayName: 'Rehan Raza',
        firstName: 'Rehan',
        lastName: 'Raza',
        emailVerified: true,
        createdAt: DateTime.now(),
        status: 'active',
      ),
    );
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String firstName,
    required String lastName,
  }) async {}
}

void main() {
  testWidgets('ProfileScreen renders user information and edit form correctly', (WidgetTester tester) async {
    final mockRepo = MockUserRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
          userRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ProfileScreen(uid: 'test_uid_123'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and fields exist
    expect(find.text('Profile Settings'), findsOneWidget);
    expect(find.text('Rehan Raza'), findsWidgets);
    expect(find.text('rehan@securevote.com'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Account Security'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify edit mode toggle
    final editButtonFinder = find.byIcon(Icons.edit_outlined);
    expect(editButtonFinder, findsOneWidget);

    await tester.tap(editButtonFinder);
    await tester.pumpAndSettle();

    // Verify save changes button appears when editing
    expect(find.text('Save Changes'), findsOneWidget);
  });
}

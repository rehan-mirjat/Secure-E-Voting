import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/presentation/email_verification_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockAuthServiceWithSignOut implements AuthService {
  bool signOutCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => null;

  @override
  bool get isEmailVerified => false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  testWidgets('EmailVerificationScreen sign out button triggers signOut() on AuthService', (WidgetTester tester) async {
    final mockAuth = MockAuthServiceWithSignOut();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuth),
        ],
        child: const MaterialApp(
          home: EmailVerificationScreen(),
        ),
      ),
    );

    // Verify Sign Out button is present
    final signOutButtonFinder = find.text('Sign Out / Use Different Account');
    expect(signOutButtonFinder, findsOneWidget);

    // Tap Sign Out button
    await tester.tap(signOutButtonFinder);
    await tester.pump();

    // Verify AuthService.signOut() was invoked
    expect(mockAuth.signOutCalled, isTrue);
  });
}

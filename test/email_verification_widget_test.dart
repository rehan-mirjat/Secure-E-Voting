import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/presentation/email_verification_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => null;

  @override
  bool get isEmailVerified => false;
}

void main() {
  testWidgets('EmailVerificationScreen renders UI elements correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: EmailVerificationScreen(),
        ),
      ),
    );

    // Verify main components exist
    expect(find.text('Verify Your Email Address'), findsOneWidget);
    expect(find.text("I've Verified My Email"), findsOneWidget);
    expect(find.text('Resend Verification Email'), findsOneWidget);
    expect(find.text('Sign Out / Use Different Account'), findsOneWidget);
  });
}

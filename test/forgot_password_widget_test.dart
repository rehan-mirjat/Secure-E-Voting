import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/presentation/forgot_password_screen.dart';
import 'package:secure_e_voting/services/auth_service.dart';

class MockAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  User? get currentUser => null;

  @override
  bool get isEmailVerified => false;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

void main() {
  testWidgets('ForgotPasswordScreen renders UI elements and validates empty inputs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      ),
    );

    // Verify main components exist
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email Address'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);

    // Test empty email validation
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });
}

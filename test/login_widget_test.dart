import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/presentation/login_screen.dart';
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
  testWidgets('LoginScreen renders UI elements correctly and validates empty inputs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify main components exist
    expect(find.text('Welcome Back'), findsOneWidget);
    // Since we separated labels from the InputDecoration 'labelText', we find by independent text widget.
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In Securely'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Test form validation: scroll to submit and tap with empty inputs
    final submitButton = find.text('Sign In Securely');
    await tester.dragUntilVisible(
      submitButton,
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}

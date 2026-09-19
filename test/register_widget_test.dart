import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_e_voting/features/auth/presentation/register_screen.dart';

void main() {
  testWidgets('RegisterScreen form validation and UI elements render correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    // Locate widgets
    final firstNameFinder = find.widgetWithText(TextFormField, 'First Name');
    final lastNameFinder = find.widgetWithText(TextFormField, 'Last Name');
    final emailFinder = find.widgetWithText(TextFormField, 'Email Address');
    final passwordFinder = find.widgetWithText(TextFormField, 'Password');
    final confirmPasswordFinder = find.widgetWithText(TextFormField, 'Confirm Password');
    final submitButtonFinder = find.text('Create Identity');

    expect(firstNameFinder, findsOneWidget);
    expect(lastNameFinder, findsOneWidget);
    expect(emailFinder, findsOneWidget);
    expect(passwordFinder, findsOneWidget);
    expect(confirmPasswordFinder, findsOneWidget);
    expect(submitButtonFinder, findsOneWidget);

    // Test form validation: tap submit with empty fields
    await tester.tap(submitButtonFinder);
    await tester.pump();

    expect(find.text('First Name is required'), findsOneWidget);
    expect(find.text('Last Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}

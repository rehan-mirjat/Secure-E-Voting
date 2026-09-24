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

    // Locate widgets using independent text labels instead of InputDecoration labels
    final submitButtonFinder = find.text('Create Identity Securely');

    expect(find.text('FIRST NAME'), findsOneWidget);
    expect(find.text('LAST NAME'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('CONFIRM PASSWORD'), findsOneWidget);
    
    // We scroll until the button is visible because the wrapper makes the layout scrollable on mobile
    await tester.dragUntilVisible(
      submitButtonFinder,
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(submitButtonFinder);
    await tester.pump();

    expect(find.text('First Name is required'), findsOneWidget);
    expect(find.text('Last Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}

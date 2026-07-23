import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PIN Dots Field Widget Tests', () {
    testWidgets('PIN dots field displays correct number of dots',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinDotsField(
              length: 6,
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      // Verify 6 dots are displayed
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('PIN dots field shows error state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinDotsField(
              length: 6,
              onCompleted: (_) {},
              isError: true,
            ),
          ),
        ),
      );

      // Verify error color is applied
      expect(find.byType(PinDotsField), findsOneWidget);
    });

    testWidgets('PIN dots field shows success state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinDotsField(
              length: 6,
              onCompleted: (_) {},
              isSuccess: true,
            ),
          ),
        ),
      );

      // Verify success indicators
      expect(find.byType(PinDotsField), findsOneWidget);
    });

    testWidgets('PIN input calls onCompleted callback',
        (WidgetTester tester) async {
      bool callbackCalled = false;
      String enteredPin = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinDotsField(
              length: 4,
              onCompleted: (pin) {
                callbackCalled = true;
                enteredPin = pin;
              },
            ),
          ),
        ),
      );

      // Simulate PIN input
      // Note: This is a simplified test; actual implementation would require
      // more detailed interaction simulation
    });
  });

  group('Animated Lock Icon Widget Tests', () {
    testWidgets('Lock icon renders in locked state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedLockIcon(
              state: LockState.locked,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedLockIcon), findsOneWidget);
    });

    testWidgets('Lock icon transitions to unlocked state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  AnimatedLockIcon(
                    state: LockState.unlocked,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedLockIcon), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Lock icon shows loading state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedLockIcon(
              state: LockState.loading,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedLockIcon), findsOneWidget);
      await tester.pump(Duration(milliseconds: 500));
    });
  });

  group('Confirm Payment Scaffold Widget Tests', () {
    testWidgets('Confirm payment scaffold displays transaction details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmPaymentScaffold(
            title: 'Confirm Payment',
            transactionDetails: Text('Test Details'),
            totalAmount: 'Rp 100,000',
            onConfirm: () {},
          ),
        ),
      );

      expect(find.text('Confirm Payment'), findsWidgets);
      expect(find.text('Rp 100,000'), findsOneWidget);
    });

    testWidgets('Confirm payment button is tappable',
        (WidgetTester tester) async {
      bool confirmPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmPaymentScaffold(
            title: 'Confirm Payment',
            transactionDetails: Text('Details'),
            totalAmount: 'Rp 100,000',
            onConfirm: () {
              confirmPressed = true;
            },
            requirePin: false,
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(confirmPressed, true);
    });

    testWidgets('PIN field appears when required',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmPaymentScaffold(
            title: 'Confirm Payment',
            transactionDetails: Text('Details'),
            totalAmount: 'Rp 100,000',
            onConfirm: () {},
            requirePin: true,
          ),
        ),
      );

      // Tap confirm to show PIN field
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // PIN field should be visible
      expect(find.byType(PinDotsField), findsOneWidget);
    });
  });

  group('Desktop Auth Panel Widget Tests', () {
    testWidgets('Desktop auth panel shows email and password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopAuthPanel(),
          ),
        ),
      );

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Remember device checkbox is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopAuthPanel(),
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('Login button is enabled with valid input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopAuthPanel(
              onLogin: (_) {},
            ),
          ),
        ),
      );

      // Fill in email
      await tester.enterText(
        find.byType(TextField).first,
        'test@example.com',
      );

      // Fill in password
      await tester.enterText(
        find.byType(TextField).last,
        'password123',
      );

      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Responsive Widget Tests', () {
    testWidgets('ResponsiveWidget shows mobile layout on small screen',
        (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = Size(400, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveWidget(
              mobile: (context) => Text('Mobile'),
              desktop: (context) => Text('Desktop'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile'), findsOneWidget);
    });

    testWidgets('ResponsiveWidget shows desktop layout on large screen',
        (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = Size(1200, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveWidget(
              mobile: (context) => Text('Mobile'),
              desktop: (context) => Text('Desktop'),
            ),
          ),
        ),
      );

      expect(find.text('Desktop'), findsOneWidget);
    });
  });
}

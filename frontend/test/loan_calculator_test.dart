// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : loan_calculator_test.dart
// Description   : Unit tests 5.2.6 — Loan Calculator EMI computation
//                 (LC01–LC05). Flutter widget tests driving the real
//                 _calculate() logic through the screen. 100% local —
//                 no backend, no network.
// First Written : 18-07-2026
// Edited on     : 18-07-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_neobanking/screens/discover/loan_calculator_screen.dart';

Future<void> pumpCalculator(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoanCalculatorScreen()));
}

Future<void> enterLoan(WidgetTester tester,
    {required String principal, required String rate, required String tenure}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), principal); // Loan Amount (RM)
  await tester.enterText(fields.at(1), rate);      // Annual Interest Rate (%)
  await tester.enterText(fields.at(2), tenure);    // Tenure (Months)
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('5.2.6 Loan Calculator — EMI computation', () {

    testWidgets('LC01: flat rate RM10,000 @5% ×12m → EMI RM875.00, total RM10,500.00',
        (tester) async {
      await pumpCalculator(tester);
      await tapText(tester, 'Flat Rate'); // switch mode (_isFlat = true)
      await enterLoan(tester, principal: '10000', rate: '5', tenure: '12');
      await tapText(tester, 'Calculate');

      expect(find.text('RM 875.00'), findsOneWidget);    // Monthly EMI
      expect(find.text('RM 10,500.00'), findsOneWidget); // Total Payment
      expect(find.text('RM 500.00'), findsOneWidget);    // Total Interest
      expect(find.text('12 months'), findsOneWidget);    // schedule generated
    });

    testWidgets('LC02: reducing balance RM10,000 @5% ×12m → EMI RM856.07',
        (tester) async {
      await pumpCalculator(tester);
      // 'Reducing' is the default mode — no toggle needed
      await enterLoan(tester, principal: '10000', rate: '5', tenure: '12');
      await tapText(tester, 'Calculate');

      expect(find.text('RM 856.07'), findsOneWidget);  // Monthly EMI
      expect(find.text('RM 272.90'), findsOneWidget);  // Total Interest
      expect(find.text('Reducing Balance'), findsOneWidget);
    });

    testWidgets('LC03: same inputs — reducing interest (272.90) < flat interest (500.00)',
        (tester) async {
      await pumpCalculator(tester);

      // Pass 1: flat rate
      await tapText(tester, 'Flat Rate');
      await enterLoan(tester, principal: '10000', rate: '5', tenure: '12');
      await tapText(tester, 'Calculate');
      expect(find.text('RM 500.00'), findsOneWidget);   // flat interest

      // Pass 2: switch to reducing (toggle clears results), recalculate
      await tapText(tester, 'Reducing');
      await tapText(tester, 'Calculate');
      expect(find.text('RM 272.90'), findsOneWidget);   // reducing interest — lower
      expect(find.text('RM 500.00'), findsNothing);     // flat result gone
    });

    testWidgets('LC04: RM5,000 @6% ×6m reducing → 6-row schedule, final balance RM0.00',
        (tester) async {
      await pumpCalculator(tester);
      await enterLoan(tester, principal: '5000', rate: '6', tenure: '6');
      await tapText(tester, 'Calculate');

      expect(find.text('RM 847.98'), findsOneWidget);  // Monthly EMI
      expect(find.text('6 months'), findsOneWidget);   // 6 schedule rows

      await tapText(tester, 'Amortization Schedule');  // expand the table
      expect(find.text('RM 0.00'), findsOneWidget);    // final row balance = 0
    });

    testWidgets('LC05: zero interest RM6,000 @0% ×12m → EMI RM500.00, no error',
        (tester) async {
      await pumpCalculator(tester);
      await enterLoan(tester, principal: '6000', rate: '0', tenure: '12');
      await tapText(tester, 'Calculate');

      expect(find.text('RM 500.00'), findsOneWidget);  // 6000 / 12 — no division error
      expect(find.text('RM 0.00'), findsOneWidget);    // Total Interest = 0
      expect(find.text('12 months'), findsOneWidget);
      expect(tester.takeException(), isNull);          // nothing thrown
    });
  });
}

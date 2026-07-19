import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/presentation/pages/wage_calculator_page.dart';

void main() {
  testWidgets('daily mode calculates and shows net pay for an hourly rate at minimum wage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WageCalculatorPage()),
    );

    await tester.enterText(find.widgetWithText(TextField, '시급'), '10320');
    await tester.tap(find.widgetWithText(FilledButton, '계산하기'));
    await tester.pump();

    expect(find.text('실수령액'), findsOneWidget);
    expect(find.textContaining('81,817원'), findsOneWidget);
    expect(find.textContaining('최저임금'), findsNothing);
  });

  testWidgets('flags a below-minimum-wage hourly rate', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WageCalculatorPage()),
    );

    await tester.enterText(find.widgetWithText(TextField, '시급'), '9000');
    await tester.tap(find.widgetWithText(FilledButton, '계산하기'));
    await tester.pump();

    expect(find.textContaining('최저임금'), findsOneWidget);
  });

  testWidgets('switching to monthly mode shows monthly-specific fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WageCalculatorPage()),
    );

    await tester.tap(find.text('상용직(월급)'));
    await tester.pump();

    expect(find.widgetWithText(TextField, '월급(세전)'), findsOneWidget);
    expect(find.widgetWithText(TextField, '부양가족 수(본인 포함)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '월급(세전)'), '2000000');
    await tester.tap(find.widgetWithText(FilledButton, '계산하기'));
    await tester.pump();

    expect(find.text('실수령액'), findsOneWidget);
    expect(find.textContaining('국민연금'), findsOneWidget);
  });

  testWidgets('shows a snackbar when calculating without an amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WageCalculatorPage()),
    );

    await tester.tap(find.widgetWithText(FilledButton, '계산하기'));
    await tester.pump();

    expect(find.text('급여 금액을 입력해 주세요.'), findsOneWidget);
  });
}

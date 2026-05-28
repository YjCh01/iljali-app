import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/presentation/widgets/work_date_range_picker_field.dart';

void main() {
  testWidgets('WorkDateRangePickerField parses committed range text', (tester) async {
    final controller = TextEditingController(text: '2026-05-01 ~ 2026-05-10');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkDateRangePickerField(controller: controller),
        ),
      ),
    );

    expect(find.textContaining('2026-05-01'), findsOneWidget);
    expect(find.textContaining('2026-05-10'), findsOneWidget);
  });

  testWidgets('WorkDateRangePickerField opens calendar sheet on tap', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkDateRangePickerField(controller: controller),
        ),
      ),
    );

    await tester.tap(find.text('근무일·시간 선택'));
    await tester.pumpAndSettle();

    expect(find.textContaining('드래그'), findsOneWidget);
    expect(find.text('근무 시간'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('WorkDateRangePickerField parses date and time text', (tester) async {
    final controller =
        TextEditingController(text: '2026-05-01 ~ 2026-05-10 · 10:00~19:00');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkDateRangePickerField(controller: controller),
        ),
      ),
    );

    expect(find.textContaining('10:00~19:00'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_attendance_card.dart';

CorporateAttendanceRecord _record({
  bool canEmployerConfirm = false,
  bool awaitingEmployerConfirm = false,
  bool awaitingSeekerCheckIn = false,
  bool canMarkNoShow = false,
}) {
  return CorporateAttendanceRecord(
    id: 'rec-1',
    workerName: '테스트구직자',
    jobTitle: '주방 보조',
    workDateLabel: '2026.05.31',
    appliedAt: DateTime(2026, 5, 30),
    checkInLabel: '-',
    checkOutLabel: '-',
    status: CorporateAttendanceStatus.onTime,
    canEmployerConfirm: canEmployerConfirm,
    awaitingEmployerConfirm: awaitingEmployerConfirm,
    awaitingSeekerCheckIn: awaitingSeekerCheckIn,
    workAgreementComplete: true,
    canMarkNoShow: canMarkNoShow,
  );
}

void main() {
  testWidgets('shows pre check-in coach bubble and disabled confirm button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CorporateAttendanceCard(
            record: _record(canEmployerConfirm: true, canMarkNoShow: true),
          ),
        ),
      ),
    );

    expect(find.text('아직 출근 전'), findsOneWidget);
    expect(
      find.textContaining('지원자가 현장에서 출근 확인하면'),
      findsOneWidget,
    );
    expect(find.text('출근 확정'), findsOneWidget);
    expect(find.text('출근 확인 (구직자 대기)'), findsNothing);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('enables confirm when seeker checked in', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CorporateAttendanceCard(
            record: _record(
              canEmployerConfirm: true,
              awaitingEmployerConfirm: true,
            ),
            onEmployerConfirm: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('출근 체크 완료'), findsOneWidget);
    await tester.tap(find.text('출근 확정'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

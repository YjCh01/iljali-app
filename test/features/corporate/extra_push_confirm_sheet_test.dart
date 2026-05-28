import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/presentation/widgets/extra_push_confirm_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

CorporateJobPost _postWithBase() {
  return CorporateJobPost(
    id: 'job-1',
    title: '물류센터 야간 보조',
    warehouseName: '강남 물류센터',
    hourlyWage: '10,000원',
    workSchedule: '주 5일',
    summary: '요약',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 3,
    postedAt: DateTime(2026, 5, 1),
    notificationSettings: JobPostNotificationSettings(
      basePoints: [
        PushNotificationBasePoint(
          id: 'base-1',
          coordinate: const GeoCoordinate(
            latitude: 37.5128,
            longitude: 127.0471,
          ),
          addressLabel: '서울 강남구 테헤란로',
          radiusTier: PushRadiusTier.standard1km,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('extra push confirm sheet shows map, credits, and actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showExtraPushConfirmSheet(
                    context,
                    post: _postWithBase(),
                    availablePushCredits: 4,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('지원자 모집하기'), findsWidgets);
    expect(find.text('보유 4회'), findsOneWidget);
    expect(find.text('이용권 및 패키지 구매'), findsOneWidget);
    expect(find.text('물류센터 야간 보조'), findsOneWidget);
    expect(
      find.textContaining('기본이용권은 근무지 주변에서만'),
      findsOneWidget,
    );
    expect(find.byType(PushRadiusMapPicker), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
  });

  testWidgets('cancel dismisses without result', (tester) async {
    ExtraPushConfirmResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showExtraPushConfirmSheet(
                    context,
                    post: _postWithBase(),
                    availablePushCredits: 2,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('confirm returns location result', (tester) async {
    ExtraPushConfirmResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await showExtraPushConfirmSheet(
                    context,
                    post: _postWithBase(),
                    availablePushCredits: 2,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final confirmButtons = find.widgetWithText(FilledButton, '지원자 모집하기');
    expect(confirmButtons, findsOneWidget);
    await tester.ensureVisible(confirmButtons);
    await tester.tap(confirmButtons);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.radiusTier, PushRadiusTier.standard1km);
    expect(result!.activePointIndex, 0);
    expect(result!.coordinate.latitude, closeTo(37.5128, 0.0001));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/presentation/widgets/extra_push_confirm_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _signInWithPushCredits(int credits) async {
  final profile = CorporateMemberProfile(
    companyName: '테스트',
    businessRegistrationNumber: '1234567890',
    department: '채용',
    contactPersonName: '담당',
    handlerCode: '1234',
    pushWallet: EmployerPushWallet(
      packageCredits: credits,
      locationSlotsFromPackages: credits,
      lifetimePackagesPurchased: credits,
    ),
  );
  await AuthSession.instance.signIn(
    AuthUser(
      name: '테스트',
      email: 'corp@test.com',
      memberType: MemberType.corporate,
      corporateProfile: profile,
    ),
  );
}

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AuthSession.instance.signOut();
  });

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
    expect(find.text('지역 푸시권 구매'), findsOneWidget);
    expect(find.text('물류센터 야간 보조'), findsOneWidget);
    expect(
      find.textContaining('근무지 무료 푸시(1km · 일 1회)는'),
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

  testWidgets('zero credits disables confirm and shows purchase hint',
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
                    availablePushCredits: 0,
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

    expect(find.text('보유 0회'), findsOneWidget);
    expect(
      find.textContaining('오늘 무료 근무지 푸시를 사용할 수 없습니다'),
      findsOneWidget,
    );
    final confirmButtons = find.widgetWithText(FilledButton, '지원자 모집하기');
    final button = tester.widget<FilledButton>(confirmButtons);
    expect(button.onPressed, isNull);
  });

  testWidgets('multiple zones show collapsible list collapsed by default',
      (tester) async {
    final post = _postWithBase().copyWith(
      notificationSettings: JobPostNotificationSettings(
        basePoints: [
          PushNotificationBasePoint(
            id: 'base-1',
            coordinate: const GeoCoordinate(
              latitude: 37.5128,
              longitude: 127.0471,
            ),
            addressLabel: '근무지',
            radiusTier: PushRadiusTier.standard1km,
          ),
          PushNotificationBasePoint(
            id: 'base-2',
            coordinate: const GeoCoordinate(
              latitude: 37.52,
              longitude: 127.05,
            ),
            addressLabel: '모집지역 1',
            radiusTier: PushRadiusTier.standard1km,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showExtraPushConfirmSheet(
                    context,
                    post: post,
                    availablePushCredits: 3,
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

    expect(find.text('발송 지역'), findsOneWidget);
    expect(find.text('모집지역 1'), findsNothing);

    await tester.tap(find.text('발송 지역'));
    await tester.pumpAndSettle();

    expect(find.text('근무지'), findsOneWidget);
    expect(find.text('모집지역 1'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('configure mode shows vertical zone rows with add at bottom',
      (tester) async {
    await _signInWithPushCredits(6);
    final post = _postWithBase();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showExtraPushConfirmSheet(
                    context,
                    post: post,
                    availablePushCredits: 6,
                    mode: ExtraPushSheetMode.configureZones,
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

    expect(find.text('모집지역 설정'), findsOneWidget);
    expect(find.text('모집 지역'), findsOneWidget);
    expect(find.text('발송 지역'), findsNothing);
    expect(find.text('근무지'), findsOneWidget);
    expect(find.textContaining('지역 푸시권 6회'), findsOneWidget);
    expect(find.textContaining('근무지 1 · 모집 0'), findsOneWidget);
    expect(find.textContaining('추가 가능 6곳'), findsWidgets);
    expect(find.text('저장'), findsOneWidget);
    expect(find.textContaining('모집지역 추가 (잔여 지역 푸시권'), findsOneWidget);
  });

  testWidgets('configure mode deducts push ticket when adding zones',
      (tester) async {
    await _signInWithPushCredits(14);
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
                    availablePushCredits: 14,
                    mode: ExtraPushSheetMode.configureZones,
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

    expect(find.textContaining('지역 푸시권 14회'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.textContaining('모집지역 추가 (잔여 지역 푸시권'));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('지역 푸시권 11회'), findsOneWidget);
    expect(find.textContaining('근무지 1 · 모집 3'), findsOneWidget);
    expect(find.textContaining('추가 가능 11곳'), findsWidgets);
  });

  testWidgets('configure mode keeps badge status and add button consistent',
      (tester) async {
    await _signInWithPushCredits(14);
    final post = _postWithBase().copyWith(
      notificationSettings: JobPostNotificationSettings(
        basePoints: [
          PushNotificationBasePoint(
            id: 'base-1',
            coordinate: const GeoCoordinate(
              latitude: 37.5128,
              longitude: 127.0471,
            ),
            addressLabel: '근무지',
            radiusTier: PushRadiusTier.standard1km,
          ),
          for (var i = 1; i <= 12; i++)
            PushNotificationBasePoint(
              id: 'recruit-$i',
              coordinate: GeoCoordinate(
                latitude: 37.5128 + i * 0.001,
                longitude: 127.0471,
              ),
              addressLabel: '모집지역 $i',
              radiusTier: PushRadiusTier.standard1km,
            ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showExtraPushConfirmSheet(
                    context,
                    post: post,
                    availablePushCredits: 14,
                    mode: ExtraPushSheetMode.configureZones,
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

    expect(find.textContaining('지역 푸시권 14회'), findsOneWidget);
    expect(find.textContaining('근무지 1 · 모집 12'), findsOneWidget);
    expect(find.textContaining('추가 가능'), findsOneWidget);
    expect(find.textContaining('모집지역 추가 (잔여 지역 푸시권'), findsOneWidget);
    expect(find.text('추가 슬롯·지역 푸시권 없음'), findsNothing);
  });
}

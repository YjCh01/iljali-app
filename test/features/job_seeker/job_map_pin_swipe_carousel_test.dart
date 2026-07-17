import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/entities/map_callout_item.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_swipe_carousel.dart';
import 'package:map/features/job_seeker/presentation/widgets/shuttle_stop_callout_card.dart';
import 'package:map/core/geo/geo_coordinate.dart';

JobMapPin _pin({
  required String id,
  required String title,
  double lat = 37.5,
  double lng = 127.03,
}) {
  return JobMapPin(
    post: CorporateJobPost(
      id: id,
      title: title,
      warehouseName: '센터',
      hourlyWage: '12,000원',
      workSchedule: '주5',
      summary: '요약 $title',
      jobDescription: '상세',
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime(2026, 5, 20),
    ),
    latitude: lat,
    longitude: lng,
    companyName: '회사 $id',
    displayTier: JobMapPinDisplayTier.standard,
  );
}

CommuteRouteStop _stop({required String id, required String label}) {
  return CommuteRouteStop(
    id: id,
    label: label,
    coordinate: const GeoCoordinate(latitude: 37.51, longitude: 127.04),
  );
}

/// viewportFraction < 1 이라 이웃 카드가 화면 가장자리에 살짝 걸쳐 함께
/// 빌드될 수 있으므로, 특정 핀의 카드 안에서만 위젯을 찾는다.
Finder _cardFor(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(JobMapPinCalloutCard),
    );

void main() {
  testWidgets('swiping the carousel moves through nearby pins in order',
      (tester) async {
    final items = [
      JobPinCalloutItem(_pin(id: 'a', title: '첫번째 공고')),
      JobPinCalloutItem(_pin(id: 'b', title: '두번째 공고')),
      JobPinCalloutItem(_pin(id: 'c', title: '세번째 공고')),
    ];
    final pageChanges = <MapCalloutItem>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: JobMapPinSwipeCarousel(
              items: items,
              initialIndex: 0,
              onClose: () {},
              onViewDetail: (_) {},
              onPageChanged: pageChanges.add,
            ),
          ),
        ),
      ),
    );

    expect(_cardFor('첫번째 공고'), findsOneWidget);

    await tester.fling(_cardFor('첫번째 공고'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(pageChanges, isNotEmpty);
    expect((pageChanges.last as JobPinCalloutItem).pin.post.id, 'b');
    expect(_cardFor('두번째 공고'), findsOneWidget);

    await tester.fling(_cardFor('두번째 공고'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect((pageChanges.last as JobPinCalloutItem).pin.post.id, 'c');
    expect(_cardFor('세번째 공고'), findsOneWidget);
  });

  testWidgets('onViewDetail fires with the currently visible pin',
      (tester) async {
    final items = [
      JobPinCalloutItem(_pin(id: 'a', title: '첫번째 공고')),
      JobPinCalloutItem(_pin(id: 'b', title: '두번째 공고')),
    ];
    MapCalloutItem? tappedDetail;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: JobMapPinSwipeCarousel(
              items: items,
              initialIndex: 1,
              onClose: () {},
              onViewDetail: (item) => tappedDetail = item,
              onPageChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(_cardFor('두번째 공고'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: _cardFor('두번째 공고'),
        matching: find.text('공고 상세보기'),
      ),
    );
    await tester.pump();

    expect((tappedDetail as JobPinCalloutItem?)?.pin.post.id, 'b');
  });

  testWidgets('renders nothing for an empty item list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobMapPinSwipeCarousel(
            items: const [],
            initialIndex: 0,
            onClose: () {},
            onViewDetail: (_) {},
            onPageChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('renders a shuttle stop callout card for stop items',
      (tester) async {
    final route = CommuteRoute(
      id: 'route_1',
      companyKey: '1234567890',
      routeName: '본사 셔틀',
      stops: [_stop(id: 'stop_1', label: '정문 정류장')],
    );
    final items = [
      JobPinCalloutItem(_pin(id: 'a', title: '첫번째 공고')),
      ShuttleStopCalloutItem(route: route, stop: route.stops.first),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: JobMapPinSwipeCarousel(
              items: items,
              initialIndex: 1,
              onClose: () {},
              onViewDetail: (_) {},
              onPageChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ShuttleStopCalloutCard), findsOneWidget);
    expect(find.text('정문 정류장'), findsOneWidget);
    expect(find.text('본사 셔틀'), findsOneWidget);
  });
}

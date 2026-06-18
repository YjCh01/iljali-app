import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/features/commute/domain/entities/commute_route.dart';

import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/commute/domain/entities/shuttle_operation_guide_copy.dart';



/// 개발·QA용 데모 셔틀 노선

abstract final class CommuteRouteDemoIds {

  static const daisoSejong = 'demo_daiso_sejong_shuttle';

}



abstract final class CommuteRouteDemo {

  /// corp-alpha 테스트 — 다이소 세종물류센터 셔틀 (지도 중심부 인근 좌표)

  static CommuteRoute daisoSejongForCompany(String companyKey) {

    const stops = [

      CommuteRouteStop(

        id: 'stop_jamsil',

        label: '잠실역 2번 출구',

        coordinate: GeoCoordinate(latitude: 37.5133, longitude: 127.1002),

        departureTime: '07:30',

      ),

      CommuteRouteStop(

        id: 'stop_sports',

        label: '종합운동장역',

        coordinate: GeoCoordinate(latitude: 37.5150, longitude: 127.0736),

        departureTime: '07:45',

      ),

      CommuteRouteStop(

        id: 'stop_samseong',

        label: '삼성역 4번 출구',

        coordinate: GeoCoordinate(latitude: 37.5088, longitude: 127.0631),

        departureTime: '08:00',

      ),

      CommuteRouteStop(

        id: 'stop_daiso',

        label: '다이소 세종물류센터',

        coordinate: GeoCoordinate(latitude: 37.5128, longitude: 127.0471),

      ),

    ];

    return CommuteRoute(

      id: CommuteRouteDemoIds.daisoSejong,

      companyKey: companyKey,

      routeName: '다이소 세종물류센터 셔틀',

      stops: stops,

      overlayColorHex: '#E53935',

      active: true,

      isFreeShuttle: true,

      boardingNotes:
          '각 정류장 앞 회사 셔틀버스가 정차합니다. 예약 없이 선착순 탑승(무료). '
          '${ShuttleOperationGuideCopy.boardingWaitRecommendation}',

      vehicleGuide: '차량 앞유리에 다이소가 적혀 있습니다.',

      arrivalInstructions:
          '물류센터 정문 게이트에서 체크인 후 근무지로 안내받습니다.',

    );

  }

}



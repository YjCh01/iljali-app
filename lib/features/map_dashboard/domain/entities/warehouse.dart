import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 물류센터 + 채용 공고 도메인 엔티티
class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.jobSummary,
    required this.hourlyWage,
    required this.workCondition,
    required this.payDay,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// 채용 공고 핵심 한 줄 요약
  final String jobSummary;
  final String hourlyWage;
  final String workCondition;
  final String payDay;

  NLatLng get position => NLatLng(latitude, longitude);
}

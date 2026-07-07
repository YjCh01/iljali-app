import 'dart:math' as math;

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 사업자 소재지 vs 공고 실근무지 — 공고 등록은 막지 않고 어드민 알림만
abstract final class WorkplaceAddressMismatchService {
  /// 허용 거리(m) — 이내면 어드민 알림 없음
  static const maxDistanceMeters = 2000;

  static WorkplaceAddressMismatchResult evaluate({
    required WorkplaceAddress workplace,
    required CorporateMemberProfile? profile,
  }) {
    if (profile == null) {
      return const WorkplaceAddressMismatchResult.allowed();
    }

    final headOffice = profile.businessHeadOfficeAddress?.trim();
    if (headOffice == null || headOffice.isEmpty) {
      return WorkplaceAddressMismatchResult.notifyAdmin(
        reason: '본사 주소 미등록 상태에서 다른 근무지로 공고 등록',
        headOfficeAddress: '',
        workplaceAddress: workplace.roadAddress,
      );
    }

    final workplaceCoord = workplace.coordinate;
    final headCoord = profile.businessHeadOfficeCoordinate;

    if (workplaceCoord != null && headCoord != null) {
      final dist = _distanceMeters(workplaceCoord, headCoord);
      if (dist <= maxDistanceMeters) {
        return WorkplaceAddressMismatchResult.allowed(
          note: '소재지 ${dist.round()}m 이내',
        );
      }
      return WorkplaceAddressMismatchResult.notifyAdmin(
        reason: '실근무지가 사업자 소재지($headOffice)에서 '
            '${(dist / 1000).toStringAsFixed(1)}km 떨어져 있습니다.',
        distanceMeters: dist.round(),
        headOfficeAddress: headOffice,
        workplaceAddress: workplace.roadAddress,
      );
    }

    if (_normalized(headOffice) == _normalized(workplace.roadAddress)) {
      return const WorkplaceAddressMismatchResult.allowed();
    }

    return WorkplaceAddressMismatchResult.notifyAdmin(
      reason: '실근무지「${workplace.roadAddress}」가 '
          '사업자 소재지「$headOffice」와 다릅니다.',
      headOfficeAddress: headOffice,
      workplaceAddress: workplace.roadAddress,
    );
  }

  static String _normalized(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  static double _distanceMeters(GeoCoordinate a, GeoCoordinate b) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

class WorkplaceAddressMismatchResult {
  const WorkplaceAddressMismatchResult._({
    required this.allowed,
    required this.notifyAdmin,
    this.reason,
    this.note,
    this.distanceMeters,
    this.headOfficeAddress,
    this.workplaceAddress,
  });

  const WorkplaceAddressMismatchResult.allowed({String? note})
      : this._(
          allowed: true,
          notifyAdmin: false,
          note: note,
        );

  const WorkplaceAddressMismatchResult.notifyAdmin({
    required String reason,
    required String headOfficeAddress,
    required String workplaceAddress,
    int? distanceMeters,
  }) : this._(
          allowed: true,
          notifyAdmin: true,
          reason: reason,
          distanceMeters: distanceMeters,
          headOfficeAddress: headOfficeAddress,
          workplaceAddress: workplaceAddress,
        );

  /// 공고 등록·게시 허용 여부 (불일치여도 true)
  final bool allowed;

  /// 어드민 근무지·본사 불일치 패널로 전송
  final bool notifyAdmin;

  @Deprecated('Use notifyAdmin')
  bool get requiresAdminReview => notifyAdmin;

  final String? reason;
  final String? note;
  final int? distanceMeters;
  final String? headOfficeAddress;
  final String? workplaceAddress;
}

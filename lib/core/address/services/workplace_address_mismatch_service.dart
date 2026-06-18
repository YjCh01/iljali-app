import 'dart:math' as math;

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 사업자 소재지 vs 공고 실근무지 검증
abstract final class WorkplaceAddressMismatchService {
  /// 허용 거리(m) — 소재지 기준 실근무지 반경
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
      return const WorkplaceAddressMismatchResult.blocked(
        reason: '사업자 본사 주소를 먼저 등록해야 공고를 올릴 수 있습니다.',
        distanceMeters: 0,
        headOfficeAddress: '',
        workplaceAddress: '',
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
      return WorkplaceAddressMismatchResult.blocked(
        reason: '실근무지가 사업자 소재지(${headOffice})에서 '
            '${(dist / 1000).toStringAsFixed(1)}km 떨어져 있습니다. '
            '소재지와 동일·인근(2km)만 등록할 수 있습니다.',
        distanceMeters: dist.round(),
        headOfficeAddress: headOffice,
        workplaceAddress: workplace.roadAddress,
      );
    }

    if (_normalized(headOffice) == _normalized(workplace.roadAddress)) {
      return const WorkplaceAddressMismatchResult.allowed();
    }

    return WorkplaceAddressMismatchResult.flagged(
      reason: '실근무지「${workplace.roadAddress}」가 '
          '사업자 소재지「$headOffice」와 다릅니다. 관리자 검토가 필요합니다.',
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
    required this.requiresAdminReview,
    this.reason,
    this.note,
    this.distanceMeters,
    this.headOfficeAddress,
    this.workplaceAddress,
  });

  const WorkplaceAddressMismatchResult.allowed({String? note})
      : this._(
          allowed: true,
          requiresAdminReview: false,
          note: note,
        );

  const WorkplaceAddressMismatchResult.flagged({
    required String reason,
    required String headOfficeAddress,
    required String workplaceAddress,
  }) : this._(
          allowed: false,
          requiresAdminReview: true,
          reason: reason,
          headOfficeAddress: headOfficeAddress,
          workplaceAddress: workplaceAddress,
        );

  const WorkplaceAddressMismatchResult.blocked({
    required String reason,
    required int distanceMeters,
    required String headOfficeAddress,
    required String workplaceAddress,
  }) : this._(
          allowed: false,
          requiresAdminReview: true,
          reason: reason,
          distanceMeters: distanceMeters,
          headOfficeAddress: headOfficeAddress,
          workplaceAddress: workplaceAddress,
        );

  final bool allowed;
  final bool requiresAdminReview;
  final String? reason;
  final String? note;
  final int? distanceMeters;
  final String? headOfficeAddress;
  final String? workplaceAddress;
}

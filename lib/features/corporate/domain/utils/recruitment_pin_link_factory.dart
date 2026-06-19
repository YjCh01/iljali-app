import 'package:flutter/material.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

/// 일자리 알림핀 — 근무지(0번)와의 연결선
abstract final class RecruitmentPinLinkFactory {
  static const defaultLinkColor = Color(0xFF9B86F0);

  /// 구직자 지도 — 알림핀 탭 시 근무지↔알림핀 실선 (연보라)
  static const seekerLinkColor = Color(0xFFD4CBFB);

  static List<PushRadiusMapPolyline> headquarterDashedLinks({
    required List<PushNotificationBasePoint> points,
  }) {
    if (points.length < 2) return [];
    final hq = points.first.coordinate;
    final links = <PushRadiusMapPolyline>[];
    for (var i = 1; i < points.length; i++) {
      final pin = points[i];
      links.add(
        PushRadiusMapPolyline(
          points: [hq, pin.coordinate],
          color: pin.resolvedPinColor,
          dashed: true,
        ),
      );
    }
    return links;
  }

  /// 구직자 — 선택한 알림핀 1곳 ↔ 근무지 실선
  static List<PushRadiusMapPolyline> seekerSolidLink({
    required GeoCoordinate workplace,
    required GeoCoordinate alertPin,
    Color? color,
  }) {
    return [
      PushRadiusMapPolyline(
        points: [workplace, alertPin],
        color: color ?? seekerLinkColor,
        dashed: false,
      ),
    ];
  }
}

extension PushNotificationBasePointColorX on PushNotificationBasePoint {
  Color get resolvedPinColor {
    final hex = pinColorHex?.trim();
    if (hex == null || hex.isEmpty) {
      return RecruitmentPinLinkFactory.defaultLinkColor;
    }
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return RecruitmentPinLinkFactory.defaultLinkColor;
    return Color(parsed);
  }
}

import 'package:map/features/job_seeker/domain/data/seeker_work_region_catalog.dart';

/// 도로명 주소 → 희망 근무 지역 라벨 (시·군·구)
abstract final class SeekerRegionFromAddress {
  static const _sidoPrefix = <String, String>{
    '서울특별시': '서울',
    '부산광역시': '부산',
    '대구광역시': '대구',
    '인천광역시': '인천',
    '광주광역시': '광주',
    '대전광역시': '대전',
    '울산광역시': '울산',
    '세종특별자치시': '세종',
    '세종시': '세종',
    '경기도': '경기',
    '강원특별자치도': '강원',
    '강원도': '강원',
    '충청북도': '충북',
    '충청남도': '충남',
    '전북특별자치도': '전북',
    '전라북도': '전북',
    '전라남도': '전남',
    '경상북도': '경북',
    '경상남도': '경남',
    '제주특별자치도': '제주',
    '제주도': '제주',
  };

  /// [roadAddress] → `경기 의정부시`, `서울 강남구`, `경기 용인시 수지구` 등
  static String? districtFromRoadAddress(String? roadAddress) {
    final trimmed = roadAddress?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    if (trimmed.startsWith('세종')) {
      return SeekerWorkRegionCatalog.normalize('세종');
    }

    for (final entry in _sidoPrefix.entries) {
      if (!trimmed.startsWith(entry.key)) continue;
      return _regionFromRest(entry.value, trimmed.substring(entry.key.length).trim());
    }

    for (final short in SeekerWorkRegionCatalog.sidos) {
      if (trimmed == short) {
        return SeekerWorkRegionCatalog.normalize(short);
      }
      if (trimmed.startsWith('$short ')) {
        return _regionFromRest(
          short,
          trimmed.substring(short.length).trim(),
        );
      }
    }

    return null;
  }

  static String? _regionFromRest(String sidoLabel, String rest) {
    if (rest.isEmpty) return SeekerWorkRegionCatalog.normalize(sidoLabel);

    final parts = rest.split(RegExp(r'\s+'));
    if (parts.isEmpty) return SeekerWorkRegionCatalog.normalize(sidoLabel);

    final unitParts = <String>[];
    var index = 0;
    while (index < parts.length) {
      final part = parts[index];
      final isUnit = part.endsWith('구') ||
          part.endsWith('시') ||
          part.endsWith('군');
      if (!isUnit) break;

      unitParts.add(part);
      if (part.endsWith('구') || part.endsWith('군')) break;

      if (part.endsWith('시') &&
          index + 1 < parts.length &&
          parts[index + 1].endsWith('구')) {
        index++;
        continue;
      }
      break;
    }

    if (unitParts.isEmpty) {
      return SeekerWorkRegionCatalog.normalize(sidoLabel);
    }
    final raw = '$sidoLabel ${unitParts.join(' ')}';
    return SeekerWorkRegionCatalog.normalize(raw) ?? raw;
  }

  @Deprecated('Use districtFromRoadAddress')
  static String? presetFromRoadAddress(String? roadAddress) =>
      districtFromRoadAddress(roadAddress);

  static bool isValidSelection(String region) =>
      SeekerWorkRegionCatalog.isValidLabel(region);
}

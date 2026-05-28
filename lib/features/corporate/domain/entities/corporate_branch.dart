import 'package:map/core/geo/geo_coordinate.dart';

/// 지점 계층 — 본사 · 지역 · 매장
enum BranchLevel {
  hq,
  regional,
  store,
}

extension BranchLevelX on BranchLevel {
  String get label => switch (this) {
        BranchLevel.hq => '본사',
        BranchLevel.regional => '지역',
        BranchLevel.store => '매장',
      };

  int get sortOrder => switch (this) {
        BranchLevel.hq => 0,
        BranchLevel.regional => 1,
        BranchLevel.store => 2,
      };
}

/// Multi-지점 — 사업자(companyKey) 하위 본사·지역·매장
class CorporateBranch {
  const CorporateBranch({
    required this.id,
    required this.companyKey,
    required this.name,
    required this.roadAddress,
    this.level = BranchLevel.store,
    this.parentBranchId,
    this.managerName,
    this.managerHandlerCode,
    this.coordinate,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String companyKey;
  final String name;
  final String roadAddress;
  final BranchLevel level;
  final String? parentBranchId;
  final String? managerName;
  final String? managerHandlerCode;
  final GeoCoordinate? coordinate;
  final bool isActive;
  final DateTime? createdAt;

  String get displayLabel => name.isNotEmpty ? name : roadAddress;

  String hierarchyLabel(String? parentName) {
    final prefix = level.label;
    if (parentName != null && parentName.isNotEmpty) {
      return '$prefix · $name ($parentName 하위)';
    }
    return '$prefix · $name';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'name': name,
        'roadAddress': roadAddress,
        'level': level.name,
        'parentBranchId': parentBranchId,
        'managerName': managerName,
        'managerHandlerCode': managerHandlerCode,
        'latitude': coordinate?.latitude,
        'longitude': coordinate?.longitude,
        'isActive': isActive,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory CorporateBranch.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    return CorporateBranch(
      id: json['id'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
      level: _parseLevel(json['level'] as String?),
      parentBranchId: json['parentBranchId'] as String?,
      managerName: json['managerName'] as String?,
      managerHandlerCode: json['managerHandlerCode'] as String?,
      coordinate: lat != null && lng != null
          ? GeoCoordinate(latitude: lat, longitude: lng)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  static BranchLevel _parseLevel(String? raw) {
    if (raw == null) return BranchLevel.store;
    try {
      return BranchLevel.values.byName(raw);
    } on ArgumentError {
      return BranchLevel.store;
    }
  }

  CorporateBranch copyWith({
    String? name,
    String? roadAddress,
    BranchLevel? level,
    String? parentBranchId,
    String? managerName,
    bool? isActive,
  }) {
    return CorporateBranch(
      id: id,
      companyKey: companyKey,
      name: name ?? this.name,
      roadAddress: roadAddress ?? this.roadAddress,
      level: level ?? this.level,
      parentBranchId: parentBranchId ?? this.parentBranchId,
      managerName: managerName ?? this.managerName,
      managerHandlerCode: managerHandlerCode,
      coordinate: coordinate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

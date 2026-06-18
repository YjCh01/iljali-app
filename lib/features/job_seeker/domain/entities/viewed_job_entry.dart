import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 오늘 지도·목록에서 열어본 공고 (보관과 별도)
class ViewedJobEntry {
  const ViewedJobEntry({
    required this.postId,
    required this.viewedAt,
    required this.title,
    required this.companyName,
    this.warehouseName = '',
    this.hourlyWage = '',
    this.latitude,
    this.longitude,
    this.expiresAt,
  });

  final String postId;
  final DateTime viewedAt;
  final String title;
  final String companyName;
  final String warehouseName;
  final String hourlyWage;
  final double? latitude;
  final double? longitude;
  final DateTime? expiresAt;

  static ViewedJobEntry fromPin(JobMapPin pin, {DateTime? viewedAt}) {
    final post = pin.post;
    return ViewedJobEntry(
      postId: post.id,
      viewedAt: viewedAt ?? DateTime.now(),
      title: post.title,
      companyName: pin.companyName,
      warehouseName: post.warehouseName,
      hourlyWage: post.hourlyWage,
      latitude: pin.latitude != 0 ? pin.latitude : null,
      longitude: pin.longitude != 0 ? pin.longitude : null,
      expiresAt: post.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'viewedAt': viewedAt.toIso8601String(),
        'title': title,
        'companyName': companyName,
        'warehouseName': warehouseName,
        'hourlyWage': hourlyWage,
        'latitude': latitude,
        'longitude': longitude,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory ViewedJobEntry.fromJson(Map<String, dynamic> json) {
    return ViewedJobEntry(
      postId: json['postId'] as String? ?? '',
      viewedAt: DateTime.tryParse(json['viewedAt'] as String? ?? '') ??
          DateTime.now(),
      title: json['title'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      warehouseName: json['warehouseName'] as String? ?? '',
      hourlyWage: json['hourlyWage'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}

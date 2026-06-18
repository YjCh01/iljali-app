import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 지도·목록에서 보관한 공고
class JobBookmark {
  const JobBookmark({
    required this.postId,
    required this.folderId,
    required this.savedAt,
    required this.title,
    required this.companyName,
    required this.warehouseName,
    required this.hourlyWage,
    this.memo = '',
    this.latitude,
    this.longitude,
    this.expiresAt,
  });

  final String postId;
  final String folderId;
  final DateTime savedAt;
  final String title;
  final String companyName;
  final String warehouseName;
  final String hourlyWage;
  final String memo;
  final double? latitude;
  final double? longitude;
  final DateTime? expiresAt;

  JobBookmark copyWith({
    String? folderId,
    DateTime? savedAt,
    String? title,
    String? companyName,
    String? warehouseName,
    String? hourlyWage,
    String? memo,
    double? latitude,
    double? longitude,
    DateTime? expiresAt,
  }) {
    return JobBookmark(
      postId: postId,
      folderId: folderId ?? this.folderId,
      savedAt: savedAt ?? this.savedAt,
      title: title ?? this.title,
      companyName: companyName ?? this.companyName,
      warehouseName: warehouseName ?? this.warehouseName,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      memo: memo ?? this.memo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  static JobBookmark fromPin(
    JobMapPin pin, {
    required String folderId,
    DateTime? savedAt,
  }) {
    final post = pin.post;
    return JobBookmark(
      postId: post.id,
      folderId: folderId,
      savedAt: savedAt ?? DateTime.now(),
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
        'folderId': folderId,
        'savedAt': savedAt.toIso8601String(),
        'title': title,
        'companyName': companyName,
        'warehouseName': warehouseName,
        'hourlyWage': hourlyWage,
        'memo': memo,
        'latitude': latitude,
        'longitude': longitude,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory JobBookmark.fromJson(Map<String, dynamic> json) {
    return JobBookmark(
      postId: json['postId'] as String? ?? '',
      folderId:
          json['folderId'] as String? ?? JobBookmarkFolder.defaultFolderId,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
      title: json['title'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      warehouseName: json['warehouseName'] as String? ?? '',
      hourlyWage: json['hourlyWage'] as String? ?? '',
      memo: json['memo'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
}

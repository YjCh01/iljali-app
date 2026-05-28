/// 고용주(기업·지점) 평가
class EmployerRating {
  const EmployerRating({
    required this.id,
    required this.companyKey,
    required this.applicationId,
    required this.seekerEmail,
    required this.stars,
    required this.createdAt,
    this.branchId,
    this.tags = const [],
    this.comment,
  });

  final String id;
  final String companyKey;
  final String applicationId;
  final String seekerEmail;
  final int stars;
  final DateTime createdAt;
  final String? branchId;
  final List<String> tags;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'applicationId': applicationId,
        'seekerEmail': seekerEmail,
        'stars': stars,
        'createdAt': createdAt.toIso8601String(),
        'branchId': branchId,
        'tags': tags,
        'comment': comment,
      };

  factory EmployerRating.fromJson(Map<String, dynamic> json) {
    return EmployerRating(
      id: json['id'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      applicationId: json['applicationId'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      stars: json['stars'] as int? ?? 5,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      branchId: json['branchId'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      comment: json['comment'] as String?,
    );
  }
}

class EmployerRatingSummary {
  const EmployerRatingSummary({
    required this.averageStars,
    required this.reviewCount,
    required this.topTags,
  });

  final double averageStars;
  final int reviewCount;
  final List<String> topTags;

  String get displayStars => reviewCount == 0
      ? '평가 없음'
      : '${averageStars.toStringAsFixed(1)}★ ($reviewCount)';
}

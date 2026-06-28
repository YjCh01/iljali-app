/// 어드민이 배치하거나 만료된 무료 공고에서 생성되는 마감유령핀
class ClosedGhostPin {
  const ClosedGhostPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.label = '',
    this.sourcePostId,
    this.createdAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final String? sourcePostId;
  final DateTime? createdAt;

  factory ClosedGhostPin.fromJson(Map<String, dynamic> json) {
    return ClosedGhostPin(
      id: json['id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? '',
      sourcePostId: json['source_post_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        if (sourcePostId != null) 'source_post_id': sourcePostId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

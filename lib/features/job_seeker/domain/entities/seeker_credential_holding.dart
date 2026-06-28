/// 구직자 보유 자격 (표준 DB ID + 사진)
class SeekerCredentialHolding {
  const SeekerCredentialHolding({
    required this.credentialId,
    this.imagePath,
    this.updatedAt,
  });

  final String credentialId;
  final String? imagePath;
  final DateTime? updatedAt;

  bool get hasPhoto => imagePath != null && imagePath!.trim().isNotEmpty;

  /// 사진 등록 완료 = 보유로 간주
  bool get isComplete => hasPhoto;

  SeekerCredentialHolding copyWith({
    String? imagePath,
    DateTime? updatedAt,
    bool clearImagePath = false,
  }) {
    return SeekerCredentialHolding(
      credentialId: credentialId,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'credentialId': credentialId,
        if (imagePath != null) 'imagePath': imagePath,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory SeekerCredentialHolding.fromJson(Map<String, dynamic> json) {
    return SeekerCredentialHolding(
      credentialId: json['credentialId'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

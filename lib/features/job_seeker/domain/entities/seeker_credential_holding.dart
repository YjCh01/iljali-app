/// 구직자 보유 자격 (표준 DB ID + 사진 · custom_* 는 직접 등록)
class SeekerCredentialHolding {
  const SeekerCredentialHolding({
    required this.credentialId,
    this.customLabel,
    this.imagePath,
    this.updatedAt,
  });

  final String credentialId;

  /// 표준 목록 외 자격증 — 사용자가 입력한 이름
  final String? customLabel;
  final String? imagePath;
  final DateTime? updatedAt;

  bool get hasPhoto => imagePath != null && imagePath!.trim().isNotEmpty;

  /// 사진 등록 완료 = 보유로 간주
  bool get isComplete => hasPhoto;

  SeekerCredentialHolding copyWith({
    String? customLabel,
    String? imagePath,
    DateTime? updatedAt,
    bool clearImagePath = false,
    bool clearCustomLabel = false,
  }) {
    return SeekerCredentialHolding(
      credentialId: credentialId,
      customLabel:
          clearCustomLabel ? null : (customLabel ?? this.customLabel),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'credentialId': credentialId,
        if (customLabel != null && customLabel!.trim().isNotEmpty)
          'customLabel': customLabel!.trim(),
        if (imagePath != null) 'imagePath': imagePath,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory SeekerCredentialHolding.fromJson(Map<String, dynamic> json) {
    return SeekerCredentialHolding(
      credentialId: json['credentialId'] as String? ?? '',
      customLabel: json['customLabel'] as String?,
      imagePath: json['imagePath'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

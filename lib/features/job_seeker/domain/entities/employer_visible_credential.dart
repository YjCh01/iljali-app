/// 기업회원에게 노출하는 자격증 요약 (채용 확정 전: 이름·보유 여부만)
class EmployerVisibleCredential {
  const EmployerVisibleCredential({
    required this.credentialId,
    required this.label,
    required this.isHeld,
    this.imagePath,
  });

  final String credentialId;
  final String label;
  final bool isHeld;

  /// 채용 확정 후에만 채워짐 — 자격증 원본 이미지 경로
  final String? imagePath;

  bool get canViewDocument =>
      isHeld && imagePath != null && imagePath!.trim().isNotEmpty;
}

import 'package:map/core/compliance/services/business_verification_service.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';

/// 사업자등록증 OCR ↔ 사용자 입력 교차검증
abstract final class OcrBusinessCrossCheck {
  static const double minConfidence = 0.75;

  static void validateStrict({
    required BusinessCertificateOcrResult ocr,
    required String expectedBrn,
    required String expectedCompanyName,
    String? expectedRepresentativeName,
  }) {
    final mismatch = detectMismatch(
      ocr: ocr,
      expectedBrn: expectedBrn,
      expectedCompanyName: expectedCompanyName,
      expectedRepresentativeName: expectedRepresentativeName,
    );
    if (mismatch != null) {
      throw BusinessVerificationException(mismatch);
    }
  }

  /// 불일치 시 관리자 검토 사유 문자열, 일치 시 null
  static String? detectMismatch({
    required BusinessCertificateOcrResult ocr,
    required String expectedBrn,
    required String expectedCompanyName,
    String? expectedRepresentativeName,
    bool blockOnRepresentativeMismatch = true,
  }) {
    final brnReason = _detectBrnMismatch(ocr, expectedBrn);
    if (brnReason != null) return brnReason;

    final companyReason = _detectCompanyMismatch(ocr, expectedCompanyName);
    if (companyReason != null) return companyReason;

    final confidenceReason = _detectConfidenceMismatch(ocr);
    if (confidenceReason != null) return confidenceReason;

    if (!blockOnRepresentativeMismatch) return null;

    return _detectRepresentativeMismatch(
      ocr: ocr,
      expectedRepresentativeName: expectedRepresentativeName,
    );
  }

  /// 국세청 확인 통과 후 — 대표자명 OCR 불일치만 별도 검출 (가입 차단 아님)
  static String? detectRepresentativeMismatch({
    required BusinessCertificateOcrResult ocr,
    String? expectedRepresentativeName,
  }) =>
      _detectRepresentativeMismatch(
        ocr: ocr,
        expectedRepresentativeName: expectedRepresentativeName,
      );

  static bool isRepresentativeOnlyMismatch(String? reason) =>
      reason != null && reason.contains('대표자명');

  static String? _detectBrnMismatch(
    BusinessCertificateOcrResult ocr,
    String expectedBrn,
  ) {
    final normalizedBrn = _digitsOnly(expectedBrn);
    final ocrBrn = _digitsOnly(ocr.businessRegistrationNumber);
    if (ocrBrn.length == 10 && ocrBrn != normalizedBrn) {
      return 'OCR 사업자번호($ocrBrn)가 입력값($normalizedBrn)과 일치하지 않습니다.';
    }
    return null;
  }

  static String? _detectCompanyMismatch(
    BusinessCertificateOcrResult ocr,
    String expectedCompanyName,
  ) {
    if (!_companyNameMatches(ocr.companyName, expectedCompanyName)) {
      return 'OCR 상호「${ocr.companyName}」가 입력 상호와 일치하지 않습니다.';
    }
    return null;
  }

  static String? _detectConfidenceMismatch(BusinessCertificateOcrResult ocr) {
    if (ocr.confidence < minConfidence) {
      return 'OCR 신뢰도가 낮습니다 (${ocr.confidence.toStringAsFixed(2)}). 관리자 검토가 필요합니다.';
    }
    return null;
  }

  static String? _detectRepresentativeMismatch({
    required BusinessCertificateOcrResult ocr,
    String? expectedRepresentativeName,
  }) {
    final rep = expectedRepresentativeName?.trim() ?? '';
    if (rep.isEmpty) return null;
    if (_representativeMatches(ocr.representativeName, rep)) return null;
    final ocrLabel = ocr.representativeName.trim();
    final ocrHint = ocrLabel.isEmpty ? '' : ' (OCR: $ocrLabel)';
    return '등록증 OCR 대표자명이 입력값과 다릅니다$ocrHint. '
        '국세청 확인이 완료되었다면 계속 진행되며, 관리자가 등록증을 검토합니다.';
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static bool _companyNameMatches(String a, String b) {
    final na = _normalizeCompany(a);
    final nb = _normalizeCompany(b);
    if (na.isEmpty || nb.isEmpty) return true;
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  static String _normalizeCompany(String value) {
    return value
        .replaceAll(RegExp(r'[\s\(\)（）\[\]「」·.]'), '')
        .replaceAll('주식회사', '')
        .replaceAll('(주)', '')
        .toLowerCase();
  }

  static String _normalizePersonName(String value) {
    var v = value.trim();
    if (RegExp(r'^대표자').hasMatch(v)) {
      v = v.replaceFirst(RegExp(r'^대표자\s*'), '');
    }
    return v
        .replaceAll(RegExp(r'[\s　]+'), '')
        .replaceAll(RegExp(r'[·・∙•．\.]'), '')
        .replaceAll(RegExp(r'[\(\)（）\[\]「」『』【】]'), '')
        .replaceAll(RegExp(r'ocr', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^가-힣a-zA-Z]'), '');
  }

  static bool _representativeMatches(String ocrName, String expected) {
    final a = _normalizePersonName(ocrName);
    final b = _normalizePersonName(expected);
    if (a.isEmpty || b.isEmpty) return true;
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return _fuzzyKoreanNameMatch(a, b);
  }

  /// OCR 오인식 1~2자 허용 (2~3글자 이름은 1자, 그 이상은 2자)
  static bool _fuzzyKoreanNameMatch(String a, String b) {
    if ((a.length - b.length).abs() > 2) return false;
    final maxDist = a.length <= 3 || b.length <= 3 ? 1 : 2;
    return _levenshtein(a, b) <= maxDist;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final rows = a.length + 1;
    final cols = b.length + 1;
    final matrix = List.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = 0; i < rows; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      matrix[0][j] = j;
    }
    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return matrix[a.length][b.length];
  }
}

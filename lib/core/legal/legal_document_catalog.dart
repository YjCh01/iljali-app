import 'package:flutter/services.dart';

/// 앱·스토어에 비치하는 약관·정책 원문 (`assets/legal/*.md`)
class LegalDocumentEntry {
  const LegalDocumentEntry({
    required this.id,
    required this.title,
    required this.assetPath,
    this.shortTabLabel,
    this.consentVersionKey,
  });

  final String id;
  final String title;
  final String assetPath;
  final String? shortTabLabel;
  final String? consentVersionKey;
}

abstract final class LegalDocumentCatalog {
  static const entries = <LegalDocumentEntry>[
    LegalDocumentEntry(
      id: 'terms',
      title: '이용약관',
      shortTabLabel: '이용약관',
      assetPath: 'assets/legal/01_terms_of_service.md',
      consentVersionKey: 'terms',
    ),
    LegalDocumentEntry(
      id: 'privacy',
      title: '개인정보처리방침',
      shortTabLabel: '개인정보',
      assetPath: 'assets/legal/02_privacy_policy.md',
      consentVersionKey: 'privacy',
    ),
    LegalDocumentEntry(
      id: 'privacy_consent',
      title: '개인정보 수집·이용 동의',
      shortTabLabel: '수집동의',
      assetPath: 'assets/legal/03_privacy_consent_notice.md',
    ),
    LegalDocumentEntry(
      id: 'electronic_finance',
      title: '전자금융거래 이용약관',
      shortTabLabel: '전자금융',
      assetPath: 'assets/legal/04_electronic_finance.md',
      consentVersionKey: 'electronicFinance',
    ),
    LegalDocumentEntry(
      id: 'paid_refund',
      title: '유료서비스·환불정책',
      shortTabLabel: '환불',
      assetPath: 'assets/legal/05_paid_service_refund.md',
    ),
    LegalDocumentEntry(
      id: 'location',
      title: '위치기반서비스 이용약관',
      shortTabLabel: '위치',
      assetPath: 'assets/legal/06_location_based.md',
    ),
    LegalDocumentEntry(
      id: 'outsourcing',
      title: '아웃소싱·인력공급 이용 제한',
      shortTabLabel: '아웃소싱',
      assetPath: 'assets/legal/07_outsourcing_restrictions.md',
      consentVersionKey: 'outsourcing',
    ),
    LegalDocumentEntry(
      id: 'marketing',
      title: '마케팅 정보 수신 동의',
      shortTabLabel: '마케팅',
      assetPath: 'assets/legal/08_marketing_consent.md',
    ),
    LegalDocumentEntry(
      id: 'community',
      title: '커뮤니티·채팅 운영정책',
      shortTabLabel: '채팅',
      assetPath: 'assets/legal/09_community_chat.md',
    ),
    LegalDocumentEntry(
      id: 'seeker_document_consent',
      title: '신분증·통장사본 수집·이용 동의',
      shortTabLabel: '서류동의',
      assetPath: 'assets/legal/10_seeker_document_consent.md',
      consentVersionKey: 'seekerDocument',
    ),
    LegalDocumentEntry(
      id: 'criminal_record_consent',
      title: '범죄경력조회 동의서',
      shortTabLabel: '범죄경력',
      assetPath: 'assets/legal/11_criminal_record_consent.md',
    ),
  ];

  static LegalDocumentEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static Future<String> load(LegalDocumentEntry entry) =>
      rootBundle.loadString(entry.assetPath);

  static Future<String> loadById(String id) async {
    final entry = byId(id);
    if (entry == null) {
      throw ArgumentError.value(id, 'id', 'unknown legal document');
    }
    return load(entry);
  }

  static Future<Map<String, String>> loadAll() async {
    final result = <String, String>{};
    for (final entry in entries) {
      result[entry.id] = await load(entry);
    }
    return result;
  }
}

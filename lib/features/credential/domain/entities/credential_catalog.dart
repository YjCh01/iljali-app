import 'package:map/features/credential/domain/entities/credential_category.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';

/// 현장 필수 자격·면허 표준 목록 (자유 입력 불가)
abstract final class CredentialCatalog {
  // ── 건설 및 제조·중장비 ──
  static const constructionSafetyBasic = CredentialDefinition(
    id: 'construction_safety_basic',
    label: '건설업 기초안전보건교육 이수증',
    category: CredentialCategory.constructionManufacturing,
    aliases: ['건설안전', '기초안전보건', '안전교육', '4시간'],
  );

  static const specialHealthExam = CredentialDefinition(
    id: 'special_health_exam',
    label: '특수건강진단 결과서',
    category: CredentialCategory.constructionManufacturing,
    aliases: ['특수검진', '배치전검진', '야간작업', '분진', '소음', '화학물질'],
  );

  static const constructionMachineryLicense = CredentialDefinition(
    id: 'construction_machinery_license',
    label: '건설기계조종사 면허증',
    category: CredentialCategory.constructionManufacturing,
    aliases: ['건설기계', '굴착기', '지게차', '조종사', '구청'],
  );

  static const forkliftOperatorCert = CredentialDefinition(
    id: 'forklift_operator_cert',
    label: '지게차 운전기능사',
    category: CredentialCategory.constructionManufacturing,
    aliases: ['지게차', '포크리프트', '기능사'],
  );

  // ── 물류 및 유통·운전 ──
  static const drivingCareerCertificate = CredentialDefinition(
    id: 'driving_career_certificate',
    label: '운전경력증명서 (전체 경력)',
    category: CredentialCategory.logisticsDriving,
    aliases: ['운전경력', '경력증명', '경찰서', '음주운전', '사고이력', '지입'],
  );

  static const freightTransportLicense = CredentialDefinition(
    id: 'freight_transport_license',
    label: '화물운송종사 자격증',
    category: CredentialCategory.logisticsDriving,
    aliases: ['화물', '화물운송', '택배', '영업용', '교통안전공단'],
  );

  static const busDriverLicense = CredentialDefinition(
    id: 'bus_driver_license',
    label: '버스운전자격증',
    category: CredentialCategory.logisticsDriving,
    aliases: ['버스', '버스운전', '승합', '통근버스'],
  );

  static const cngGasSafetyTraining = CredentialDefinition(
    id: 'cng_gas_safety_training',
    label: 'CNG·고압가스 안전교육 이수증',
    category: CredentialCategory.logisticsDriving,
    aliases: ['CNG', '압축천연가스', '고압가스', '가스버스'],
  );

  // ── 시설관리 및 경비 ──
  static const statutoryFacilityLicense = CredentialDefinition(
    id: 'statutory_facility_license',
    label: '법정 자격증 및 선임 이력',
    category: CredentialCategory.facilitySecurity,
    aliases: [
      '전기기사',
      '소방설비',
      '공조냉동',
      '안전관리자',
      '선임',
      '시설관리',
    ],
  );

  static const securityGuardTraining = CredentialDefinition(
    id: 'security_guard_training',
    label: '일반경비원 신임교육 이수증',
    category: CredentialCategory.facilitySecurity,
    aliases: ['경비', '경비원', '신임교육', '24시간', '보안'],
  );

  static const criminalRecordConsent = CredentialDefinition(
    id: 'criminal_record_consent',
    label: '범죄경력조회 동의서',
    category: CredentialCategory.facilitySecurity,
    aliases: ['범죄경력', '성범죄', '아동학대', '경비채용'],
    requiresPhoto: false,
    guideDocumentId: 'criminal_record_consent',
    summary: '경비·시설 채용 시 범죄경력 확인 동의',
  );

  // ── 미화 및 요양·돌봄 ──
  static const latentTbScreening = CredentialDefinition(
    id: 'latent_tb_screening',
    label: '잠복결핵 검진 결과서',
    category: CredentialCategory.cleaningCare,
    aliases: ['잠복결핵', '결핵', 'TB', '미화', '조리'],
  );

  static const caregiverCert = CredentialDefinition(
    id: 'caregiver_cert',
    label: '요양보호사 자격증',
    category: CredentialCategory.cleaningCare,
    aliases: ['요양', '요양보호', '돌봄'],
  );

  static const childcareTeacherCert = CredentialDefinition(
    id: 'childcare_teacher_cert',
    label: '보육교사 자격증',
    category: CredentialCategory.cleaningCare,
    aliases: ['보육', '보육교사', '어린이집', '유치원'],
  );

  // ── 식품·외식·제조 ──
  static const healthCertificate = CredentialDefinition(
    id: 'health_certificate',
    label: '보건증 (건강진단결과서)',
    category: CredentialCategory.foodService,
    summary: '식품·요식업 종사 필수 · e보건소·보건소·병원 발급',
    aliases: [
      '보건',
      '보건증',
      '건강진단결과서',
      '건강진단',
      '건강증명서',
      '위생교육',
      '식품위생',
      '외식',
      '조리',
      '식품',
      '식품제조',
      '요식업',
      'HACCP',
      '감염병',
      '보건소',
      'e보건소',
    ],
  );

  static const List<CredentialDefinition> _offlineDefaults = [
    constructionSafetyBasic,
    specialHealthExam,
    constructionMachineryLicense,
    forkliftOperatorCert,
    drivingCareerCertificate,
    freightTransportLicense,
    busDriverLicense,
    cngGasSafetyTraining,
    statutoryFacilityLicense,
    securityGuardTraining,
    criminalRecordConsent,
    latentTbScreening,
    caregiverCert,
    childcareTeacherCert,
    healthCertificate,
  ];

  /// 서버 카탈로그(`GET /v1/credentials/catalog`)가 성공하면 이 캐시를 덮어씀 —
  /// 앱 재배포 없이 항목 추가 가능. 실패 시(오프라인 등) 위 15종 기본값 유지.
  static List<CredentialDefinition> _cache = _offlineDefaults;

  static List<CredentialDefinition> get all => _cache;

  /// 테스트 전용 — 캐시를 오프라인 기본값으로 리셋.
  static void resetToOfflineDefaultsForTest() => _cache = _offlineDefaults;

  /// 서버 응답(JSON 목록)으로 캐시 교체 — 파싱 실패 항목은 건너뜀.
  static void overrideFromServer(List<Map<String, dynamic>> items) {
    final parsed = <CredentialDefinition>[];
    for (final item in items) {
      final id = item['id'] as String?;
      final label = item['label'] as String?;
      final categoryName = item['category'] as String?;
      if (id == null || label == null || categoryName == null) continue;
      CredentialCategory? category;
      for (final candidate in CredentialCategory.values) {
        if (candidate.name == categoryName) {
          category = candidate;
          break;
        }
      }
      if (category == null) continue;
      parsed.add(
        CredentialDefinition(
          id: id,
          label: label,
          category: category,
          aliases: (item['aliases'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
          requiresPhoto: item['requires_photo'] as bool? ?? true,
          summary: item['summary'] as String?,
          guideDocumentId: item['guide_document_id'] as String?,
        ),
      );
    }
    if (parsed.isNotEmpty) _cache = parsed;
  }

  static CredentialDefinition? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<CredentialDefinition> forCategory(CredentialCategory category) =>
      all.where((c) => c.category == category).toList();

  static List<String> labelsForIds(Iterable<String> ids) => ids
      .map(findById)
      .whereType<CredentialDefinition>()
      .map((c) => c.label)
      .toList();
}

import 'package:map/features/corporate/domain/entities/worker_category.dart';

/// MVP 제품 범위 — `--dart-define` 플래그로 기능 on/off.
///
/// 비활성 기능 코드는 삭제하지 않고 UI·동기화 등 진입점만 차단합니다.
/// AI/개발자 조회: [listDisabledFeatures] 또는 `map/docs/disabled_features.md`
abstract final class ProductFeatureFlags {
  static const bool enableWorkerGeneral = bool.fromEnvironment(
    'ENABLE_WORKER_GENERAL',
    defaultValue: false,
  );

  static const bool enableWorkerContract = bool.fromEnvironment(
    'ENABLE_WORKER_CONTRACT',
    defaultValue: true,
  );

  /// 물류·식품 제조 제휴사 선택 위저드 (쿠팡·다이소 등)
  static const bool enablePremiumPartnerWizard = bool.fromEnvironment(
    'ENABLE_PREMIUM_PARTNER_WIZARD',
    defaultValue: true,
  );

  /// 아웃소싱·도급 기업 플로우
  static const bool enableEnterpriseOutsourcing = bool.fromEnvironment(
    'ENABLE_ENTERPRISE_OUTSOURCING',
    defaultValue: true,
  );

  /// 일용직 채용 성공 수수료 — 제휴 연계 채널 전용. 메인 앱 기본 비활성.
  static const bool enableHiringCommission = bool.fromEnvironment(
    'ENABLE_HIRING_COMMISSION',
    defaultValue: false,
  );

  /// 근무 확정(즉시확정·상호합의)·근태 관리·출근 에스컬레이션 — 수수료와 무관하게
  /// 항상 필요한 근태 데이터 수집 흐름이라 기본 활성. 수수료 지급 자체는
  /// [enableHiringCommission]으로 계속 별도 통제.
  static const bool enableAttendanceFlow = bool.fromEnvironment(
    'ENABLE_ATTENDANCE_FLOW',
    defaultValue: true,
  );

  /// 구직자 앱 — 고용주 평점·신뢰100·배지 표시 (페이즈 2)
  static const bool enableEmployerTrustDisplay = bool.fromEnvironment(
    'ENABLE_EMPLOYER_TRUST_DISPLAY',
    defaultValue: false,
  );

  /// 구직자 → 고용주 평가 다이얼로그 (페이즈 2, 구직자 신뢰는 어드민 전용 예정)
  static const bool enableSeekerEmployerRating = bool.fromEnvironment(
    'ENABLE_SEEKER_EMPLOYER_RATING',
    defaultValue: false,
  );

  static bool get isWorkerGeneralEnabled => enableWorkerGeneral;

  static bool get isWorkerContractEnabled => enableWorkerContract;

  static bool get isPremiumPartnerWizardEnabled => enablePremiumPartnerWizard;

  static bool get isEnterpriseOutsourcingEnabled => enableEnterpriseOutsourcing;

  static bool get isHiringCommissionEnabled => enableHiringCommission;

  static bool get isAttendanceFlowEnabled => enableAttendanceFlow;

  static bool get isEmployerTrustDisplayEnabled => enableEmployerTrustDisplay;

  static bool get isSeekerEmployerRatingEnabled => enableSeekerEmployerRating;

  static WorkerCategory get defaultWorkerCategory =>
      isWorkerGeneralEnabled ? WorkerCategory.general : WorkerCategory.shortTerm;

  static bool isWorkerCategoryAllowed(WorkerCategory category) =>
      allowedWorkerCategories.contains(category);

  static List<WorkerCategory> get allowedWorkerCategories => [
        if (enableWorkerGeneral) WorkerCategory.general,
        WorkerCategory.daily,
        WorkerCategory.shortTerm,
        WorkerCategory.regular,
        if (enableWorkerContract) WorkerCategory.contract,
      ];

  /// 폼·편집 UI용 — 현재 값이 비허용이면 편집 호환을 위해 포함
  static List<WorkerCategory> workerCategoriesForForm({
    required WorkerCategory current,
  }) {
    final categories = List<WorkerCategory>.from(allowedWorkerCategories);
    if (!categories.contains(current)) {
      categories.add(current);
    }
    categories.sort((a, b) => a.index.compareTo(b.index));
    return categories;
  }

  static bool isJobRoleIdAllowed(String roleId) {
    final category = workerCategoryFromRoleId(roleId);
    return category != null && isWorkerCategoryAllowed(category);
  }

  static List<DisabledFeature> get disabledFeatures => [
        if (!enableWorkerGeneral)
          const DisabledFeature(
            id: 'worker_general',
            displayName: '일반직 공고',
            description: '공고 작성·위저드에서 일반(상시 아닌 정규) 고용 형태 선택',
            flagKey: 'ENABLE_WORKER_GENERAL',
            affectedFiles: [
              'lib/features/corporate/presentation/pages/corporate_create_job_post_page.dart',
              'lib/features/corporate/data/datasources/create_job_post_wizard_local_data_source.dart',
              'lib/features/corporate/presentation/widgets/corporate_job_post_form.dart',
              'lib/features/corporate/domain/entities/job_post_write_draft.dart',
            ],
            reEnableSteps:
                '빌드/실행 시 --dart-define=ENABLE_WORKER_GENERAL=true 추가. '
                '앱 재시작 후 공고 등록 위저드·작성 폼에서 「일반」 칩 확인.',
          ),
        if (!enableWorkerContract)
          const DisabledFeature(
            id: 'worker_contract',
            displayName: '계약직 공고',
            description: '공고 작성·위저드에서 계약직(상시직 채용 연계) 고용 형태 선택',
            flagKey: 'ENABLE_WORKER_CONTRACT',
            affectedFiles: [
              'lib/features/corporate/presentation/pages/corporate_create_job_post_page.dart',
              'lib/features/corporate/data/datasources/create_job_post_wizard_local_data_source.dart',
              'lib/features/corporate/presentation/widgets/corporate_job_post_form.dart',
            ],
            reEnableSteps:
                '빌드/실행 시 --dart-define=ENABLE_WORKER_CONTRACT=true 추가. '
                '계약직 선택 시 상시직 합격 플로우와 함께 검토.',
          ),
        if (!enablePremiumPartnerWizard)
          const DisabledFeature(
            id: 'premium_partner_wizard',
            displayName: '제휴사 선택 위저드',
            description: '공고 등록 시 쿠팡·다이소·CJ 등 프리미엄 제휴사 선택 플로우',
            flagKey: 'ENABLE_PREMIUM_PARTNER_WIZARD',
            affectedFiles: [
              'lib/features/corporate/presentation/pages/corporate_create_job_post_page.dart',
              'lib/features/corporate/data/datasources/create_job_post_wizard_local_data_source.dart',
            ],
            reEnableSteps:
                '기본값 true. 비활성화했던 경우 --dart-define=ENABLE_PREMIUM_PARTNER_WIZARD=true.',
          ),
        if (!enableEnterpriseOutsourcing)
          const DisabledFeature(
            id: 'enterprise_outsourcing',
            displayName: '아웃소싱·도급 기업',
            description: '대형 물류·식품 현장에 도급·아웃소싱으로 투입하는 기업 전용 플로우',
            flagKey: 'ENABLE_ENTERPRISE_OUTSOURCING',
            affectedFiles: [
              'lib/features/corporate/presentation/pages/corporate_create_job_post_page.dart',
            ],
            reEnableSteps:
                '기본값 true. 비활성화했던 경우 --dart-define=ENABLE_ENTERPRISE_OUTSOURCING=true.',
          ),
        if (!enableHiringCommission)
          const DisabledFeature(
            id: 'hiring_commission',
            displayName: '일용직 채용 성공 수수료',
            description:
                '출근 확인 후 채용 수수료 결제·미결제 배너·에스컬레이션 — 제휴 채널용',
            flagKey: 'ENABLE_HIRING_COMMISSION',
            affectedFiles: [
              'lib/core/hiring/local_hiring_repository.dart',
              'lib/features/corporate/presentation/pages/tabs/corporate_attendance_tab.dart',
              'lib/features/corporate/presentation/pages/tabs/corporate_chat_tab.dart',
              'lib/features/corporate/presentation/pages/corporate_payment_management_page.dart',
              'lib/features/corporate/presentation/pages/corporate_welcome_onboarding_page.dart',
            ],
            reEnableSteps:
                '제휴 연계 채널 빌드 시 --dart-define=ENABLE_HIRING_COMMISSION=true 추가.',
          ),
        if (!enableAttendanceFlow)
          const DisabledFeature(
            id: 'attendance_flow',
            displayName: '근무 확정·근태 관리',
            description:
                '즉시확정·근무예정 상호합의·근태 관리 탭·출근 에스컬레이션 — 수수료와'
                ' 무관하게 근태 데이터 자체를 수집하기 위한 핵심 흐름',
            flagKey: 'ENABLE_ATTENDANCE_FLOW',
            affectedFiles: [
              'lib/core/hiring/local_hiring_repository.dart',
              'lib/features/corporate/presentation/pages/tabs/corporate_attendance_tab.dart',
              'lib/features/hiring/presentation/pages/application_chat_page.dart',
            ],
            reEnableSteps: '기본값 true. 비활성화했던 경우 --dart-define=ENABLE_ATTENDANCE_FLOW=true.',
          ),
        if (!enableEmployerTrustDisplay)
          const DisabledFeature(
            id: 'employer_trust_display',
            displayName: '고용주 평점·신뢰 배지',
            description:
                '공고 상세·목록의 별점·신뢰100·우수 고용주 등 — 페이즈 2',
            flagKey: 'ENABLE_EMPLOYER_TRUST_DISPLAY',
            affectedFiles: [
              'lib/core/trust/presentation/employer_trust_section.dart',
              'lib/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart',
            ],
            reEnableSteps:
                '--dart-define=ENABLE_EMPLOYER_TRUST_DISPLAY=true',
          ),
        if (!enableSeekerEmployerRating)
          const DisabledFeature(
            id: 'seeker_employer_rating',
            displayName: '구직자 고용주 평가',
            description: '근무 완료 후 고용주 평가 다이얼로그 — 페이즈 2',
            flagKey: 'ENABLE_SEEKER_EMPLOYER_RATING',
            affectedFiles: [
              'lib/core/trust/company_rating_prompt_service.dart',
              'lib/features/job_seeker/presentation/pages/tabs/individual_work_tab.dart',
            ],
            reEnableSteps:
                '--dart-define=ENABLE_SEEKER_EMPLOYER_RATING=true',
          ),
      ];

  /// AI·운영자용 — 현재 빌드에서 꺼진 기능 목록
  static List<String> listDisabledFeatures() {
    final features = disabledFeatures;
    if (features.isEmpty) {
      return ['현재 비활성화된 기능이 없습니다. (모든 dart-define 플래그 활성)'];
    }
    return features.map((feature) {
      final files = feature.affectedFiles.map((f) => '  - $f').join('\n');
      return '• ${feature.displayName} (${feature.id})\n'
          '  ${feature.description}\n'
          '  플래그: ${feature.flagKey}=true\n'
          '  재활성: ${feature.reEnableSteps}\n'
          '  관련 파일:\n$files';
    }).toList();
  }
}

/// 비활성 기능 메타데이터 — AI 재활성·감사용
final class DisabledFeature {
  const DisabledFeature({
    required this.id,
    required this.displayName,
    required this.description,
    required this.flagKey,
    required this.affectedFiles,
    required this.reEnableSteps,
  });

  final String id;
  final String displayName;
  final String description;
  final String flagKey;
  final List<String> affectedFiles;
  final String reEnableSteps;
}

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_stop_policy.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_entitlement.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';

/// 채용 공고 고용 형태 — 일용직(출근 확인) · 상시직(재직 확인)
enum JobEmploymentType {
  daily,
  permanent,
}

extension JobEmploymentTypeX on JobEmploymentType {
  String get label => switch (this) {
        JobEmploymentType.daily => '일용직',
        JobEmploymentType.permanent => '상시직',
      };

  bool get isPermanent => this == JobEmploymentType.permanent;
}

/// 기업회원 공고 관리용 채용 공고
class CorporateJobPost {
  const CorporateJobPost({
    required this.id,
    required this.title,
    required this.warehouseName,
    required this.hourlyWage,
    required this.workSchedule,
    required this.summary,
    this.jobDescription = '',
    this.descriptionBody = const JobPostDescriptionBody(),
    required this.status,
    required this.applicantCount,
    required this.postedAt,
    this.expiresAt,
    this.employmentType = JobEmploymentType.daily,
    this.workerCategory,
    this.dailyWage,
    this.paymentDate,
    this.paymentMonthOffset,
    this.paymentDayOfMonth,
    this.paymentDateNegotiable = false,
    this.workPeriodNegotiable = false,
    this.notificationSettings,
    this.registeredBy,
    this.recruiterEmail,
    this.paymentRecord,
    this.branchId,
    this.branchName,
    this.mapPinDisplayTier,
    this.commuteRouteId,
    this.linkedCommuteRouteIds = const [],
    this.shuttleRegisteredStopIdsByRoute = const {},
    this.shuttlePaidStopIdsByRoute = const {},
    this.shuttleExposurePaidAt,
    this.hasShuttleRouteOverlay = false,
    this.workCategoryId,
    this.workplaceLatitude,
    this.workplaceLongitude,
    this.requiredResumeItems = const [],
    this.requiredCredentialIds = const [],
  });

  final String id;
  final String title;
  final JobEmploymentType employmentType;

  /// 공고 고용 유형 (일반 · 일용직 · 계약직). 구버전은 null → [effectiveWorkerCategory]
  final WorkerCategory? workerCategory;

  /// 근무지 표시명 (도로명 주소 또는 센터명)
  final String warehouseName;

  /// 근무지 좌표 — 알림핀 미설정 공고·지도 중심용
  final double? workplaceLatitude;
  final double? workplaceLongitude;

  /// 지원 시 구직자에게 공개 요청할 이력서 항목
  final List<ResumeItemKind> requiredResumeItems;

  /// 필수 제출 자격·면허 (표준 DB ID)
  final List<String> requiredCredentialIds;

  final String hourlyWage;
  final String? dailyWage;
  final String workSchedule;
  final String summary;

  /// 업무 내용 (요약·추가 내용과 분리)
  final String jobDescription;

  /// 업무 내용 본문 — 텍스트·HTML·이미지 (상세 화면 전용)
  final JobPostDescriptionBody descriptionBody;
  final DateTime? paymentDate;

  /// null이면 [paymentDate] 절대일 모드 (일용직)
  final SalaryPaymentMonthOffset? paymentMonthOffset;
  final int? paymentDayOfMonth;

  /// 일용직 급여지급일 — 구인·구직자 협의
  final bool paymentDateNegotiable;

  /// 정규직 근무기간 — 첫 근무 시작일 협의 가능
  final bool workPeriodNegotiable;

  final JobPostNotificationSettings? notificationSettings;
  final CorporateMemberProfile? registeredBy;

  /// 공고 등록 담당자 이메일 (결제·위임 라우팅)
  final String? recruiterEmail;
  final JobPostPaymentRecord? paymentRecord;
  final String? branchId;
  final String? branchName;

  /// 등록 시점 지도 핀 등급
  final JobMapPinDisplayTier? mapPinDisplayTier;

  /// 연결된 셔틀·통근 노선 ID (등록은 무료) — 대표 노선(첫 연결)
  final String? commuteRouteId;

  /// 이 공고에 등록된 노선 ID 목록
  final List<String> linkedCommuteRouteIds;

  /// 이 공고에 등록한 정류장 (노선 ID → 정류장 ID 목록)
  final Map<String, List<String>> shuttleRegisteredStopIdsByRoute;

  /// 결제 완료·노출 중인 정류장 (노선 ID → 정류장 ID 목록)
  final Map<String, List<String>> shuttlePaidStopIdsByRoute;

  /// 정류장 표시핀 최근 결제 시각 (노출 종료: D+1 23:59:59)
  final DateTime? shuttleExposurePaidAt;

  /// 유료 셔틀 노선 지도 노출 활성화 — true일 때만 구직자 지도에 정류장·노선 표시
  final bool hasShuttleRouteOverlay;

  /// 업무 카테고리 (업적 뱃지) — null이면 AI 자동 분류
  final String? workCategoryId;

  final CorporateJobPostStatus status;
  final int applicantCount;
  final DateTime postedAt;
  final DateTime? expiresAt;

  CorporateJobPost copyWith({
    String? title,
    JobEmploymentType? employmentType,
    WorkerCategory? workerCategory,
    String? warehouseName,
    String? hourlyWage,
    String? dailyWage,
    String? workSchedule,
    String? summary,
    String? jobDescription,
    JobPostDescriptionBody? descriptionBody,
    DateTime? paymentDate,
    SalaryPaymentMonthOffset? paymentMonthOffset,
    int? paymentDayOfMonth,
    bool? paymentDateNegotiable,
    bool? workPeriodNegotiable,
    JobPostNotificationSettings? notificationSettings,
    CorporateMemberProfile? registeredBy,
    String? recruiterEmail,
    JobPostPaymentRecord? paymentRecord,
    String? branchId,
    String? branchName,
    JobMapPinDisplayTier? mapPinDisplayTier,
    String? commuteRouteId,
    List<String>? linkedCommuteRouteIds,
    Map<String, List<String>>? shuttleRegisteredStopIdsByRoute,
    Map<String, List<String>>? shuttlePaidStopIdsByRoute,
    DateTime? shuttleExposurePaidAt,
    bool? hasShuttleRouteOverlay,
    String? workCategoryId,
    double? workplaceLatitude,
    double? workplaceLongitude,
    List<ResumeItemKind>? requiredResumeItems,
    List<String>? requiredCredentialIds,
    CorporateJobPostStatus? status,
    int? applicantCount,
    DateTime? postedAt,
    DateTime? expiresAt,
  }) {
    return CorporateJobPost(
      id: id,
      title: title ?? this.title,
      employmentType: employmentType ?? this.employmentType,
      workerCategory: workerCategory ?? this.workerCategory,
      warehouseName: warehouseName ?? this.warehouseName,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      dailyWage: dailyWage ?? this.dailyWage,
      workSchedule: workSchedule ?? this.workSchedule,
      summary: summary ?? this.summary,
      jobDescription: jobDescription ?? this.jobDescription,
      descriptionBody: descriptionBody ?? this.descriptionBody,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMonthOffset: paymentMonthOffset ?? this.paymentMonthOffset,
      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,
      paymentDateNegotiable:
          paymentDateNegotiable ?? this.paymentDateNegotiable,
      workPeriodNegotiable:
          workPeriodNegotiable ?? this.workPeriodNegotiable,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      registeredBy: registeredBy ?? this.registeredBy,
      recruiterEmail: recruiterEmail ?? this.recruiterEmail,
      paymentRecord: paymentRecord ?? this.paymentRecord,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      mapPinDisplayTier: mapPinDisplayTier ?? this.mapPinDisplayTier,
      commuteRouteId: commuteRouteId ?? this.commuteRouteId,
      linkedCommuteRouteIds:
          linkedCommuteRouteIds ?? this.linkedCommuteRouteIds,
      shuttleRegisteredStopIdsByRoute: shuttleRegisteredStopIdsByRoute ??
          this.shuttleRegisteredStopIdsByRoute,
      shuttlePaidStopIdsByRoute:
          shuttlePaidStopIdsByRoute ?? this.shuttlePaidStopIdsByRoute,
      shuttleExposurePaidAt: shuttleExposurePaidAt ?? this.shuttleExposurePaidAt,
      hasShuttleRouteOverlay:
          hasShuttleRouteOverlay ?? this.hasShuttleRouteOverlay,
      workCategoryId: workCategoryId ?? this.workCategoryId,
      workplaceLatitude: workplaceLatitude ?? this.workplaceLatitude,
      workplaceLongitude: workplaceLongitude ?? this.workplaceLongitude,
      requiredResumeItems: requiredResumeItems ?? this.requiredResumeItems,
      requiredCredentialIds:
          requiredCredentialIds ?? this.requiredCredentialIds,
      status: status ?? this.status,
      applicantCount: applicantCount ?? this.applicantCount,
      postedAt: postedAt ?? this.postedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

enum CorporateJobPostStatus {
  recruiting,
  closingSoon,
  closed,
}

extension CorporateJobPostWorkerCategoryX on CorporateJobPost {
  WorkerCategory get effectiveWorkerCategory {
    if (workerCategory != null) return workerCategory!;
    if (employmentType == JobEmploymentType.permanent) {
      return WorkerCategory.contract;
    }
    if (paymentMonthOffset != null && paymentDayOfMonth != null) {
      return WorkerCategory.general;
    }
    if (paymentDate != null) return WorkerCategory.daily;
    return WorkerCategory.general;
  }

  /// 근무 일정 표시 — 정규직 협의 가능 시 접미
  String get workScheduleDisplayLabel {
    final base = workSchedule.trim();
    if (!workPeriodNegotiable) return base;
    if (base.isEmpty) return '협의가능';
    return '$base · 협의가능';
  }
}

extension CorporateJobPostPaymentScheduleX on CorporateJobPost {
  SalaryPaymentSchedule? get paymentSchedule =>
      salaryPaymentScheduleFromPost(this);

  String? get paymentScheduleDisplayLabel => paymentSchedule?.displayLabel;

  bool get hasCompletePaymentSchedule =>
      paymentSchedule?.isComplete ?? false;
}

extension CorporateJobPostWorkplaceCoordX on CorporateJobPost {
  GeoCoordinate? get workplaceCoordinate {
    if (workplaceLatitude != null && workplaceLongitude != null) {
      return GeoCoordinate(
        latitude: workplaceLatitude!,
        longitude: workplaceLongitude!,
      );
    }
    return null;
  }
}

extension CorporateJobPostShuttleRoutesX on CorporateJobPost {
  /// 저장된 복수 노선 또는 레거시 단일 [commuteRouteId]
  List<String> get effectiveLinkedCommuteRouteIds {
    final fromList = [
      for (final id in linkedCommuteRouteIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (fromList.isNotEmpty) return fromList;
    final single = commuteRouteId?.trim();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  int get registeredShuttleStopCount {
    var total = 0;
    for (final stopIds in shuttleRegisteredStopIdsByRoute.values) {
      total += stopIds.length;
    }
    return total;
  }

  bool get hasShuttlePinRegistration =>
      effectiveLinkedCommuteRouteIds.isNotEmpty && registeredShuttleStopCount > 0;
}

extension CorporateJobPostShuttleExposureX on CorporateJobPost {
  bool get _hasShuttlePaidExposureMetadata =>
      shuttlePaidStopIdsByRoute.isNotEmpty ||
      ShuttleExposurePolicy.isActive(shuttleExposurePaidAt);

  DateTime? get shuttleExposureExpiresAt => shuttleExposurePaidAt == null
      ? null
      : ShuttleExposurePolicy.expiresAtFromPayment(shuttleExposurePaidAt!);

  bool get isShuttleExposureActive {
    if (!hasShuttleRouteOverlay) return false;
    if (ShuttleExposurePolicy.isActive(shuttleExposurePaidAt)) return true;
    // 결제 정류장 목록만 있고 paidAt 미기록 — resolve 전에도 노출 중으로 간주
    if (shuttleExposurePaidAt == null &&
        shuttlePaidStopIdsByRoute.isNotEmpty) {
      return true;
    }
    // 구버전: overlay만 켜진 공고 — 등록 정류장 전체를 노출 중으로 간주
    return shuttleExposurePaidAt == null &&
        shuttlePaidStopIdsByRoute.isEmpty &&
        registeredShuttleStopCount > 0;
  }

  bool isShuttleStopExposureLocked(String routeId, String stopId) {
    if (!isShuttleExposureActive) return false;
    final registered = shuttleRegisteredStopIdsByRoute[routeId] ?? const [];
    if (!registered.contains(stopId)) return false;

    final paid = shuttlePaidStopIdsByRoute[routeId] ?? const [];
    if (paid.contains(stopId)) return true;
    // 구버전 overlay-only: 정류장별 결제 목록 없음 → 등록 정류장 전체 잠금
    if (shuttlePaidStopIdsByRoute.isEmpty) return true;
    return false;
  }

  int get unpaidRegisteredShuttleStopCount {
    if (!hasShuttleRouteOverlay || !isShuttleExposureActive) {
      return registeredShuttleStopCount;
    }
    if (shuttlePaidStopIdsByRoute.isEmpty) return 0;

    var unpaid = 0;
    for (final entry in shuttleRegisteredStopIdsByRoute.entries) {
      final paid = (shuttlePaidStopIdsByRoute[entry.key] ?? const []).toSet();
      for (final stopId in entry.value) {
        if (!paid.contains(stopId)) unpaid++;
      }
    }
    return unpaid;
  }

  /// overlay는 켜졌으나 결제 메타가 비어 있을 때 등록 정류장으로 보정
  CorporateJobPost resolveShuttleExposureMetadata() {
    final hasPaidMap = shuttlePaidStopIdsByRoute.isNotEmpty;
    if (!hasShuttleRouteOverlay && !hasPaidMap) {
      return this;
    }
    if (registeredShuttleStopCount == 0 && !hasPaidMap) {
      return this;
    }
    if (hasPaidMap && shuttleExposurePaidAt != null) {
      return hasShuttleRouteOverlay
          ? this
          : copyWith(hasShuttleRouteOverlay: true);
    }

    return copyWith(
      hasShuttleRouteOverlay: hasShuttleRouteOverlay || hasPaidMap,
      shuttlePaidStopIdsByRoute: hasPaidMap
          ? shuttlePaidStopIdsByRoute
          : shuttleRegisteredStopIdsByRoute,
      shuttleExposurePaidAt: shuttleExposurePaidAt ?? postedAt,
    );
  }

  /// 이 공고에 기존 결제 메타가 있을 때만 노선 [exposureActivated]와 동기화.
  /// 노선 플래그는 회사 단위이므로 미결제 공고에는 복사하지 않음.
  CorporateJobPost reconcileShuttleExposureWithRoutes(
    Iterable<CommuteRoute> routes,
  ) {
    if (!_hasShuttlePaidExposureMetadata) return this;

    final routesById = {for (final route in routes) route.id: route};
    final paidByRoute = Map<String, List<String>>.from(
      shuttlePaidStopIdsByRoute,
    );
    var changed = false;

    for (final routeId in effectiveLinkedCommuteRouteIds) {
      final route = routesById[routeId];
      if (route == null) continue;
      final registered =
          (shuttleRegisteredStopIdsByRoute[routeId] ?? const []).toSet();
      if (registered.isEmpty) continue;

      final merged = <String>{...?paidByRoute[routeId]};
      for (final stop in route.stops) {
        if (ShuttleRouteStopPolicy.isWorkplaceStop(stop)) continue;
        if (stop.exposureActivated &&
            registered.contains(stop.id) &&
            !merged.contains(stop.id)) {
          merged.add(stop.id);
          changed = true;
        }
      }
      if (merged.isNotEmpty) {
        final next = merged.toList(growable: false);
        if (!_sameStopIdList(paidByRoute[routeId], next)) {
          changed = true;
        }
        paidByRoute[routeId] = next;
      }
    }

    if (!changed) return resolveShuttleExposureMetadata();

    return copyWith(
      shuttlePaidStopIdsByRoute: paidByRoute,
      hasShuttleRouteOverlay: hasShuttleRouteOverlay || paidByRoute.isNotEmpty,
    ).resolveShuttleExposureMetadata();
  }
}

bool _sameStopIdList(List<String>? a, List<String> b) {
  if (a == null) return false;
  if (a.length != b.length) return false;
  return a.toSet().containsAll(b);
}

extension CorporateJobPostMapPinX on CorporateJobPost {
  JobMapPinDisplayTier get effectiveMapPinTier =>
      MapPinTierResolver.resolve(post: this);

  bool get showsShuttleRouteOverlay =>
      ShuttleRouteEntitlement.postEligible(this);
}

extension CorporateJobPostDisplayX on CorporateJobPost {
  DateTime get effectiveExpiresAt =>
      expiresAt ?? JobPostValidity.expiresAtFromRegistration(postedAt);

  bool get isExpired => JobPostValidity.isExpired(effectiveExpiresAt);

  bool get isActiveForSeekers =>
      !isExpired && status != CorporateJobPostStatus.closed;

  /// 상세 본문 — [descriptionBody] 우선, 구버전 plain [jobDescription] 호환
  JobPostDescriptionBody get effectiveDescriptionBody {
    if (descriptionBody.hasContent) return descriptionBody;
    final job = jobDescription.trim();
    if (job.isNotEmpty) return JobPostDescriptionBody(text: job);
    final extra = summary.trim();
    if (extra.isNotEmpty) return JobPostDescriptionBody(text: extra);
    return const JobPostDescriptionBody();
  }

  /// 구버전(합쳐진 summary만 있는 공고) 호환 — plain 텍스트 fallback
  String get fullDescriptionText => effectiveDescriptionBody.legacyPlainText;
}

extension CorporateJobPostStatusX on CorporateJobPostStatus {
  String get label => switch (this) {
        CorporateJobPostStatus.recruiting => '모집중',
        CorporateJobPostStatus.closingSoon => '마감임박',
        CorporateJobPostStatus.closed => '마감',
      };
}

import 'dart:typed_data';

import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/dev_experience_flags.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_import_result.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/services/job_post_ai_summary_service.dart';
import 'package:map/features/corporate/domain/services/job_post_import_demo_samples.dart';
import 'package:map/features/corporate/domain/services/job_post_text_parser.dart';
import 'package:map/core/dev/qc_demo_addresses.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/services/mock_job_post_screenshot_ocr_service.dart';
import 'package:map/features/corporate/domain/services/workplace_address_resolver.dart';

/// 외부 플랫폼 공고 → 일자리 작성 초안
class ExternalJobPostImportService {
  ExternalJobPostImportService({
    IljariApiClient? apiClient,
    MockJobPostScreenshotOcrService? ocrService,
  })  : _api = apiClient ?? IljariApiClient(),
        _ocr = ocrService ?? const MockJobPostScreenshotOcrService();

  final IljariApiClient _api;
  final MockJobPostScreenshotOcrService _ocr;

  Future<ExternalJobPostImportResult> importFromUrl(String url) async {
    final trimmed = url.trim();
    final platform = ExternalJobPostPlatform.detectFromUrl(trimmed);

    if (_api.isEnabled) {
      try {
        final remote = await _api.importJobPost(
          url: trimmed,
          platform: platform.name,
        );
        final text = remote['raw_text'] as String? ?? '';
        final descriptionBody = _descriptionBodyFromRemote(remote);
        if (text.isNotEmpty || descriptionBody.hasContent) {
          var parsed = JobPostTextParser.parse(
            text: text,
            platform: platform,
            sourceUrl: trimmed,
          );
          final remoteTitle = (remote['title'] as String?)?.trim() ?? '';
          if (remoteTitle.isNotEmpty) {
            parsed = parsed.copyWith(title: remoteTitle);
          }
          final remoteWage = remote['hourly_wage'] as String?;
          if (remoteWage != null && remoteWage.isNotEmpty) {
            parsed = parsed.copyWith(hourlyWage: remoteWage);
          }
          final remoteSchedule = (remote['work_schedule'] as String?)?.trim();
          if (remoteSchedule != null && remoteSchedule.isNotEmpty) {
            parsed = parsed.copyWith(workSchedule: remoteSchedule);
          }
          final remotePlace = (remote['workplace'] as String?)?.trim();
          if (remotePlace != null && remotePlace.isNotEmpty) {
            parsed = parsed.copyWith(workplaceAddress: remotePlace);
          }
          final remoteDesc = (remote['job_description'] as String?)?.trim();
          if (remoteDesc != null && remoteDesc.isNotEmpty) {
            parsed = parsed.copyWith(jobDescription: remoteDesc);
          }
          if (descriptionBody.hasContent) {
            parsed = parsed.copyWith(
              descriptionBody: descriptionBody,
              jobDescription: remoteDesc?.isNotEmpty == true
                  ? remoteDesc!
                  : descriptionBody.legacyPlainText,
            );
          }
          return parsed.copyWith(
            confidence: (remote['confidence'] as num?)?.toDouble() ?? 0.75,
          );
        }
      } catch (_) {
        // fallback below
      }
    }

    if (DevExperienceFlags.enabled) {
      return JobPostTextParser.parse(
        text: _demoTextForPlatform(platform, trimmed),
        platform: platform,
        sourceUrl: trimmed,
      ).copyWith(
        warnings: const [
          'QC 데모 — 가져온 내용을 등록 전에 꼭 확인해 주세요.',
        ],
      );
    }

    return JobPostTextParser.parse(
      text: '',
      platform: platform,
      sourceUrl: trimmed,
    ).copyWith(
      warnings: const [
        '링크를 자동으로 불러올 수 없습니다. 「텍스트」 탭에 공고 내용을 붙여넣어 주세요.',
      ],
    );
  }

  Future<ExternalJobPostImportResult> importFromText({
    required String text,
    ExternalJobPostPlatform? platform,
    String? sourceUrl,
  }) async {
    return JobPostTextParser.parse(
      text: text,
      platform: platform ?? ExternalJobPostPlatform.unknown,
      sourceUrl: sourceUrl,
    );
  }

  Future<ExternalJobPostImportResult> importFromScreenshot({
    required Uint8List imageBytes,
    required String fileName,
    ExternalJobPostPlatform platform = ExternalJobPostPlatform.unknown,
  }) async {
    if (!DevExperienceFlags.enabled) {
      return JobPostTextParser.parse(
        text: '',
        platform: platform,
      ).copyWith(
        warnings: const [
          '캡처 자동 인식은 준비 중입니다. 「텍스트」 탭에 공고 내용을 붙여넣어 주세요.',
        ],
      );
    }
    final ocrText = await _ocr.extractText(
      imageBytes: imageBytes,
      fileName: fileName,
      platform: platform,
    );
    return JobPostTextParser.parse(
      text: ocrText,
      platform: platform,
    ).copyWith(
      warnings: [
        '캡처 인식 결과입니다. 틀린 항목은 등록 화면에서 수정해 주세요.',
      ],
    );
  }

  Future<JobPostWriteDraft> buildDraftWithAiSummary({
    required ExternalJobPostImportResult imported,
    required WorkerCategory workerCategory,
    DateTime? paymentDate,
  }) async {
    var resolvedCategory =
        workerCategory == ProductFeatureFlags.defaultWorkerCategory
            ? imported.inferWorkerCategory()
            : workerCategory;
    if (!ProductFeatureFlags.isWorkerCategoryAllowed(resolvedCategory)) {
      resolvedCategory = ProductFeatureFlags.defaultWorkerCategory;
    }
    final resolvedPaymentDate = paymentDate ??
        (resolvedCategory.usesAbsolutePaymentDate ||
                resolvedCategory.usesCalendarPaymentDate
            ? DateTime.now().add(const Duration(days: 7))
            : null);
    final wageLabel = imported.hourlyWage ?? const JobPostWriteDraft().hourlyWage;
    final payType = parseSalaryPayType(wageLabel);
    final paymentLabel = JobPostAiSummaryService.paymentLabel(
      workerCategory: resolvedCategory,
      paymentDate: resolvedPaymentDate,
    );
    final summary = imported.workplaceAddress != null
        ? await JobPostAiSummaryService.generate(
            JobPostAiSummaryInput(
              title: imported.title,
              workplaceLabel: imported.workplaceAddress,
              jobDescription: imported.jobDescription,
              workSchedule: imported.workSchedule,
              wageLabel: salaryPayDigits(wageLabel),
              salaryPayType: payType,
              workerCategory: resolvedCategory,
              paymentScheduleLabel: paymentLabel,
            ),
          )
        : '';

    final sourceLabel = imported.platform == ExternalJobPostPlatform.unknown
        ? '외부 공고'
        : '${imported.platform.label}에서 가져옴';

    return imported.toDraft(
      workerCategory: resolvedCategory,
      summary: summary,
      importSourceLabel: sourceLabel,
      paymentDate: resolvedPaymentDate,
    );
  }

  /// AI 요약 없이 폼에 바로 채울 초안
  JobPostWriteDraft buildDraftFromImport(ExternalJobPostImportResult imported) {
    var workerCategory = imported.inferWorkerCategory();
    if (!ProductFeatureFlags.isWorkerCategoryAllowed(workerCategory)) {
      workerCategory = ProductFeatureFlags.defaultWorkerCategory;
    }
    final paymentDate = workerCategory.usesAbsolutePaymentDate ||
            workerCategory.usesCalendarPaymentDate
        ? DateTime.now().add(const Duration(days: 7))
        : null;
    final sourceLabel = imported.platform == ExternalJobPostPlatform.unknown
        ? '외부 공고'
        : '${imported.platform.label} · 인식 ${(imported.confidence * 100).round()}%';
    return imported.toDraft(
      workerCategory: workerCategory,
      importSourceLabel: sourceLabel,
      paymentDate: paymentDate,
    );
  }

  /// 가져온 근무지 텍스트를 검색·지오코딩해 좌표가 있는 주소로 보강
  Future<WorkplaceAddress?> resolveImportedWorkplace(String? rawAddress) async {
    final trimmed = rawAddress?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (QcDemoAddresses.isLegacyDemo(trimmed)) return null;
    return WorkplaceAddressResolver.resolve(trimmed);
  }

  JobPostDescriptionBody _descriptionBodyFromRemote(
    Map<String, dynamic> remote,
  ) {
    final raw = remote['description_body'];
    if (raw is Map) {
      return JobPostDescriptionBody.fromMap(Map<String, dynamic>.from(raw));
    }
    return const JobPostDescriptionBody();
  }

  String _demoTextForPlatform(
    ExternalJobPostPlatform platform,
    String url,
  ) {
    return switch (platform) {
      ExternalJobPostPlatform.albamon =>
        '${JobPostImportDemoSamples.albamonText.trim()}\n원본: $url',
      ExternalJobPostPlatform.albacheon => '''
식품공장 단기 알바 채용
시급 11,500원 / 08:00-17:00
경기 화성시 동탄 1동
라인 보조, 청소
$url
''',
      ExternalJobPostPlatform.incruit => '''
「창고관리 보조」 채용
급여 시급 12,500원
근무 10:00-19:00 월~금
근무지 경기도 화성시 동탄대로 123
$url
''',
      ExternalJobPostPlatform.dongnealba => '''
동네 물류 알바
시급: 12000원
09:00-18:00
화성 동탄 근무
$url
''',
      ExternalJobPostPlatform.karrot => '''
당근알바 — 물류 보조
시급 12,000원 · 주5일 09~18시
경기 화성시 동탄대로 123
$url
''',
      ExternalJobPostPlatform.unknown => '''
채용 공고
시급 12,000원
09:00-18:00
$url
''',
    };
  }
}

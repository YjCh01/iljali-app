import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/dev_experience_flags.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_import_result.dart';

/// 외부 이력서 → 일자리 이력서 양식
class SeekerResumeImportService {
  SeekerResumeImportService({IljariApiClient? apiClient})
      : _api = apiClient ?? IljariApiClient();

  final IljariApiClient _api;

  static const _demoText = '''
학력
서울대학교 경영학과 졸업 2016-2020

경력
(주)아라물류 물류센터 피킹 2021.03 - 2023.12
이마트24 매장 보조 아르바이트 2019.06 - 2020.02

면허
운전면허 1종 보통

자격증
지게차운전기능사 2022.05

자기소개
성실하고 체력이 좋아 현장 업무에 자신 있습니다.
''';

  Future<SeekerResumeImportResult> importFromUrl(String url) async {
    final trimmed = url.trim();
    final platform = SeekerResumeImportPlatform.detectFromUrl(trimmed);

    if (_api.isEnabled) {
      try {
        final remote = await _api.importResume(
          url: trimmed,
          platform: platform.name,
        );
        final result = SeekerResumeImportResult.fromRemote(remote);
        if (result.hasStructuredContent || result.rawText.isNotEmpty) {
          return result;
        }
        if (result.message.isNotEmpty) {
          return result;
        }
      } catch (_) {
        // fallback
      }
    }

    if (DevExperienceFlags.enabled) {
      return _importFromText(
        text: _demoText,
        platform: platform,
        source: 'demo',
        message: 'QC 데모 이력서입니다. 실제 서비스에서는 캡처·PDF를 권장합니다.',
      );
    }

    throw StateError(
      '링크에서 이력서를 읽지 못했습니다. '
      '로그인이 필요한 페이지일 수 있습니다. 캡처나 PDF로 다시 시도해 주세요.',
    );
  }

  Future<SeekerResumeImportResult> importFromText({
    required String text,
    SeekerResumeImportPlatform platform = SeekerResumeImportPlatform.unknown,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('이력서 내용을 붙여넣어 주세요.');
    }

    if (_api.isEnabled) {
      try {
        final remote = await _api.importResume(
          text: trimmed,
          platform: platform.name,
        );
        return SeekerResumeImportResult.fromRemote(remote);
      } catch (_) {
        // local fallback below
      }
    }

    return _importFromText(
      text: trimmed,
      platform: platform,
      source: 'local',
      message: '붙여넣은 내용을 분석했습니다.',
    );
  }

  Future<SeekerResumeImportResult> importFromFile({
    required Uint8List bytes,
    required String fileName,
    SeekerResumeImportPlatform platform = SeekerResumeImportPlatform.unknown,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('파일을 읽을 수 없습니다.');
    }

    if (_api.isEnabled) {
      final remote = await _api.importResumeFile(
        fileBytes: bytes,
        fileName: fileName,
        platform: platform.name,
      );
      return SeekerResumeImportResult.fromRemote(remote);
    }

    if (DevExperienceFlags.enabled) {
      return _importFromText(
        text: _demoText,
        platform: platform,
        source: 'demo_file',
        message: 'QC 데모 — 파일 OCR 대신 샘플 이력서를 채웁니다.',
      );
    }

    throw StateError('서버 연결이 필요합니다. 잠시 후 다시 시도해 주세요.');
  }

  Future<({Uint8List bytes, String name})?> pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return (bytes: bytes, name: file.name);
  }

  SeekerResumeContent mergeIntoExisting({
    required SeekerResumeContent existing,
    required SeekerResumeContent imported,
    bool replaceSelfIntroduction = false,
  }) {
    return existing.copyWith(
      educations: [...existing.educations, ...imported.educations],
      experiences: [...existing.experiences, ...imported.experiences],
      licenses: [...existing.licenses, ...imported.licenses],
      certifications: [...existing.certifications, ...imported.certifications],
      selfIntroduction: replaceSelfIntroduction &&
              imported.selfIntroduction.trim().isNotEmpty
          ? imported.selfIntroduction.trim()
          : (existing.selfIntroduction.trim().isNotEmpty
              ? existing.selfIntroduction
              : imported.selfIntroduction.trim()),
    );
  }

  Future<SeekerResumeImportResult> _importFromText({
    required String text,
    required SeekerResumeImportPlatform platform,
    required String source,
    required String message,
  }) async {
    if (_api.isEnabled) {
      final remote = await _api.importResume(
        text: text,
        platform: platform.name,
      );
      return SeekerResumeImportResult.fromRemote(remote);
    }
    return SeekerResumeImportResult(
      resume: const SeekerResumeContent(),
      rawText: text,
      platform: platform.name,
      source: source,
      confidence: 0,
      message: message,
      warnings: [message],
    );
  }
}

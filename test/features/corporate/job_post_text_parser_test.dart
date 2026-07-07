import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';
import 'package:map/features/corporate/domain/services/external_job_post_import_service.dart';
import 'package:map/features/corporate/domain/services/job_post_import_demo_samples.dart';
import 'package:map/features/corporate/domain/services/job_post_text_parser.dart';

void main() {
  test('detects albamon from URL', () {
    expect(
      ExternalJobPostPlatform.detectFromUrl('https://www.albamon.com/job/123'),
      ExternalJobPostPlatform.albamon,
    );
  });

  test('parses wage schedule and workplace from pasted text', () {
    final result = JobPostTextParser.parse(
      text: JobPostImportDemoSamples.albamonText,
      platform: ExternalJobPostPlatform.albamon,
    );
    expect(result.title, contains('피킹'));
    expect(result.hourlyWage, contains('12000'));
    expect(result.workSchedule, contains('09:00'));
    expect(result.workplaceAddress, contains('화성시'));
  });

  test('importFromUrl without QC demo returns empty parse with guidance', () async {
    final service = ExternalJobPostImportService();
    final result = await service.importFromUrl(
      'https://www.daangn.com/kr/local-jobs/123',
    );
    expect(result.platform, ExternalJobPostPlatform.karrot);
    expect(result.hasUsableTitle, isFalse);
    expect(
      result.warnings.any((w) => w.contains('텍스트')),
      isTrue,
    );
  });

  test('buildDraftFromImport maps fields into write form draft', () {
    final parsed = JobPostTextParser.parse(
      text: JobPostImportDemoSamples.albamonText,
      platform: ExternalJobPostPlatform.albamon,
    );
    final service = ExternalJobPostImportService();
    final draft = service.buildDraftFromImport(parsed);

    expect(draft.title, contains('피킹'));
    expect(draft.workplaceAddress, contains('화성시'));
    expect(draft.hourlyWage, contains('12000'));
    expect(draft.jobDescription, isNotEmpty);
    expect(draft.importSourceLabel, contains('알바몬'));
    expect(draft.workScheduleNegotiable, isTrue);
  });
}

import 'package:map/core/constants/labor_constants.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_import_result.dart';
import 'package:map/features/corporate/domain/entities/external_job_post_platform.dart';

/// 붙여넣기·OCR 텍스트에서 공고 필드 추출
abstract final class JobPostTextParser {
  static ExternalJobPostImportResult parse({
    required String text,
    ExternalJobPostPlatform platform = ExternalJobPostPlatform.unknown,
    String? sourceUrl,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final title = _extractTitle(lines, normalized);
    final wage = _extractWage(normalized);
    final schedule = _extractSchedule(normalized);
    final workplace = _extractWorkplace(normalized);
    final description = _extractDescription(lines, title);

    final warnings = <String>[];
    if (title.isEmpty) warnings.add('제목을 직접 확인해 주세요.');
    if (wage == null) warnings.add('급여를 직접 입력해 주세요.');
    if (schedule.isEmpty) warnings.add('근무 시간을 직접 입력해 주세요.');
    if (workplace == null) warnings.add('근무지를 검색해 주세요.');

    var confidence = 0.35;
    if (title.isNotEmpty) confidence += 0.2;
    if (wage != null) confidence += 0.15;
    if (schedule.isNotEmpty) confidence += 0.15;
    if (workplace != null) confidence += 0.15;

    return ExternalJobPostImportResult(
      platform: platform,
      sourceUrl: sourceUrl,
      title: title,
      workplaceAddress: workplace,
      workSchedule: schedule,
      hourlyWage: wage ?? LaborConstants.defaultHourlyWageText,
      jobDescription: description,
      rawText: normalized,
      confidence: confidence.clamp(0.0, 1.0),
      warnings: warnings,
    );
  }

  static String _extractTitle(List<String> lines, String full) {
    final bracket = RegExp(r'[「\[]([^」\]]{2,60})[」\]]').firstMatch(full);
    if (bracket != null) return bracket.group(1)!.trim();

    for (final line in lines.take(8)) {
      if (line.length < 4 || line.length > 80) continue;
      if (_isMetaLine(line)) continue;
      if (line.contains('모집') ||
          line.contains('채용') ||
          line.contains('알바') ||
          line.contains('보조') ||
          line.contains('피킹')) {
        return line;
      }
    }
    if (lines.isNotEmpty && lines.first.length <= 60) {
      return lines.first;
    }
    return '';
  }

  static bool _isMetaLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('http') ||
        lower.contains('시급') && line.length < 12 ||
        lower.contains('www.');
  }

  static String? _extractWage(String text) {
    final hourly = RegExp(
      r'시급\s*[:：]?\s*([0-9,]{4,7})\s*원?',
      caseSensitive: false,
    ).firstMatch(text);
    if (hourly != null) {
      return '시급 ${hourly.group(1)!.replaceAll(',', '')}';
    }
    final daily = RegExp(
      r'일급\s*[:：]?\s*([0-9,]{4,7})\s*원?',
      caseSensitive: false,
    ).firstMatch(text);
    if (daily != null) {
      return '일급 ${daily.group(1)!.replaceAll(',', '')}';
    }
    final generic = RegExp(
      r'([0-9,]{4,7})\s*원\s*/?\s*시간',
      caseSensitive: false,
    ).firstMatch(text);
    if (generic != null) {
      return '시급 ${generic.group(1)!.replaceAll(',', '')}';
    }
    return null;
  }

  static String _extractSchedule(String text) {
    final range = RegExp(
      r'(\d{1,2}\s*:\s*\d{2})\s*[~\-–]\s*(\d{1,2}\s*:\s*\d{2})',
    ).firstMatch(text);
    final week = RegExp(
      r'(주\s*[0-9]일|월\s*~\s*금|월\s*-\s*금|토\s*~\s*일|격일|주말)',
      caseSensitive: false,
    ).firstMatch(text);
    if (range != null) {
      final start = range.group(1)!.replaceAll(' ', '');
      final end = range.group(2)!.replaceAll(' ', '');
      final time = '$start-$end';
      if (week != null) return '${week.group(1)} $time';
      return time;
    }
    return week?.group(1) ?? '';
  }

  static String? _extractWorkplace(String text) {
    final road = RegExp(
      r'((?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)[^\n]{4,60})',
    ).firstMatch(text);
    if (road != null) {
      final value = road.group(1)!.trim();
      if (value.length <= 80) return value;
      return value.substring(0, 80);
    }
    final addr = RegExp(
      r'근무지\s*[:：]\s*([^\n]{4,60})',
      caseSensitive: false,
    ).firstMatch(text);
    return addr?.group(1)?.trim();
  }

  static String _extractDescription(List<String> lines, String title) {
    final buffer = <String>[];
    var inDuty = false;
    for (final line in lines) {
      if (line == title) continue;
      if (line.contains('업무') ||
          line.contains('모집내용') ||
          line.contains('상세')) {
        inDuty = true;
        continue;
      }
      if (inDuty && buffer.length < 6) {
        if (_isMetaLine(line)) break;
        buffer.add(line);
      }
    }
    if (buffer.isEmpty) {
      for (final line in lines.skip(1).take(5)) {
        if (_isMetaLine(line)) continue;
        buffer.add(line);
      }
    }
    return buffer.join('\n');
  }
}

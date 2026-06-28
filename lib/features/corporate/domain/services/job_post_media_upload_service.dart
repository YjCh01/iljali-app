import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';

/// 공고 본문 이미지 업로드 — API 연동, 오프라인 시 data URL fallback
class JobPostMediaUploadService {
  JobPostMediaUploadService({IljariApiClient? client})
      : _client = client ?? IljariApiClient();

  final IljariApiClient _client;

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (EnvConfig.isComplianceApiEnabled && _client.isEnabled) {
      try {
        return await _client.uploadJobPostMedia(
          bytes: bytes,
          filename: filename,
        );
      } on Object catch (e) {
        if (kDebugMode) {
          debugPrint('JobPostMediaUploadService: server upload failed: $e');
        }
      }
    }
    final b64 = base64Encode(bytes);
    return 'data:$mimeType;base64,$b64';
  }
}

String jobPostMediaMimeType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

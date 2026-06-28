import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map/core/compliance/services/business_certificate_address_extractor.dart';
import 'package:map/core/compliance/services/mock_business_certificate_ocr_service.dart';
import 'package:map/core/config/env_config.dart';

/// 네이버 CLOVA OCR — 사업자등록증 General OCR
class ClovaBusinessCertificateOcrService implements BusinessCertificateOcrService {
  ClovaBusinessCertificateOcrService({
    http.Client? client,
    BusinessCertificateOcrService? fallback,
  })  : _client = client ?? http.Client(),
        _fallback = fallback ?? const MockBusinessCertificateOcrService();

  final http.Client _client;
  final BusinessCertificateOcrService _fallback;

  @override
  Future<BusinessCertificateOcrResult> extractFromImage({
    required String imageRef,
    required String expectedBrn,
    required String expectedCompanyName,
  }) async {
    if (!EnvConfig.isClovaOcrConfigured) {
      return _fallback.extractFromImage(
        imageRef: imageRef,
        expectedBrn: expectedBrn,
        expectedCompanyName: expectedCompanyName,
      );
    }

    try {
      final file = File(imageRef.replaceFirst('file://', ''));
      if (!await file.exists()) {
        return _fallback.extractFromImage(
          imageRef: imageRef,
          expectedBrn: expectedBrn,
          expectedCompanyName: expectedCompanyName,
        );
      }

      final bytes = await file.readAsBytes();
      final body = jsonEncode({
        'version': 'V2',
        'requestId': 'iljari-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'images': [
          {
            'format': _ext(file.path),
            'name': 'business_cert',
            'data': base64Encode(bytes),
          },
        ],
      });

      final response = await _client.post(
        Uri.parse(EnvConfig.clovaOcrInvokeUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-OCR-SECRET': EnvConfig.clovaOcrSecret,
        },
        body: body,
      );

      if (response.statusCode >= 400) {
        throw StateError('OCR HTTP ${response.statusCode}');
      }

      return _parseResponse(
        jsonDecode(response.body) as Map<String, dynamic>,
        expectedBrn: expectedBrn,
        expectedCompanyName: expectedCompanyName,
      );
    } on Object {
      return _fallback.extractFromImage(
        imageRef: imageRef,
        expectedBrn: expectedBrn,
        expectedCompanyName: expectedCompanyName,
      );
    }
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  BusinessCertificateOcrResult _parseResponse(
    Map<String, dynamic> payload, {
    required String expectedBrn,
    required String expectedCompanyName,
  }) {
    final images = payload['images'] as List<dynamic>? ?? [];
    final fields = <String, String>{};
    final lineTexts = <String>[];
    for (final image in images) {
      if (image is! Map) continue;
      final infer = image['fields'] as List<dynamic>? ?? [];
      for (final field in infer) {
        if (field is! Map) continue;
        final name = field['name']?.toString() ?? '';
        final text = field['inferText']?.toString() ?? '';
        if (name.isNotEmpty) fields[name] = text;
        if (text.isNotEmpty) lineTexts.add(text);
      }
      final lines = image['lines'] as List<dynamic>? ?? [];
      for (final line in lines) {
        if (line is! Map) continue;
        final text = line['inferText']?.toString() ?? '';
        if (text.isNotEmpty) lineTexts.add(text);
        if (text.contains('사업자') || text.contains('등록')) {
          fields.putIfAbsent('raw', () => text);
        }
      }
    }

    final brn = _extractBrn(fields, expectedBrn);
    final company = fields['companyName'] ??
        fields['상호'] ??
        fields['법인명'] ??
        expectedCompanyName;
    final industry = fields['industry'] ?? fields['업종'] ?? fields['업태'] ?? '물류·창고업';
    final rep = fields['representative'] ?? fields['대표자'] ?? '';
    final address = fields['businessAddress'] ??
        fields['사업장소재지'] ??
        fields['본점소재지'] ??
        BusinessCertificateAddressExtractor.fromOcrLines(lineTexts);

    return BusinessCertificateOcrResult(
      businessRegistrationNumber: brn,
      companyName: company,
      representativeName: rep,
      industryName: industry,
      confidence: 0.97,
      entityTypeHint: brn.startsWith('1') ? 'corporation' : 'soleProprietor',
      businessAddress: address,
    );
  }

  String _extractBrn(Map<String, String> fields, String expectedBrn) {
    final candidates = [
      fields['businessRegistrationNumber'],
      fields['사업자등록번호'],
      fields['등록번호'],
      fields['raw'],
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 10) return digits;
    }
    return expectedBrn.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

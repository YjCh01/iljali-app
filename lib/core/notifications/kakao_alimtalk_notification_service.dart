import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 카카오 알림톡(비즈메시지) 발송 — 서버 프록시 또는 로컬 MVP 큐
class KakaoAlimtalkNotificationService {
  KakaoAlimtalkNotificationService(this._prefs);

  static const _logKey = 'kakao_alimtalk_log_v1';

  final SharedPreferences _prefs;

  static Future<KakaoAlimtalkNotificationService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return KakaoAlimtalkNotificationService(prefs);
  }

  /// 상호 출근 확인 후 구인자에게 수수료 결제 알림톡
  Future<KakaoAlimtalkSendResult> notifyEmployerCommissionDue({
    required HiringApplication application,
    required String employerPhone,
    required String employerName,
  }) {
    return _send(
      templateCode: 'COMMISSION_DUE_EMPLOYER',
      recipientPhone: employerPhone,
      recipientName: employerName,
      variables: {
        'seeker_name': application.seekerName,
        'post_title': application.postTitle,
        'commission_krw': '${CommissionCalculator.forApplication(application)}',
        'application_id': application.id,
      },
      fallbackBody:
          '[일jari] ${application.seekerName}님 출근 확인 완료. '
          '「${application.postTitle}」 성공 수수료 '
          '${CommissionCalculator.formatKrw(CommissionCalculator.forApplication(application))} 결제를 진행해 주세요.',
    );
  }

  Future<KakaoAlimtalkSendResult> _send({
    required String templateCode,
    required String recipientPhone,
    required String recipientName,
    required Map<String, String> variables,
    required String fallbackBody,
  }) async {
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        final uri = Uri.parse('${EnvConfig.complianceApiBaseUrl}/v1/notifications/alimtalk');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'template_code': templateCode,
            'recipient_phone': recipientPhone,
            'recipient_name': recipientName,
            'variables': variables,
            'fallback_body': fallbackBody,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          await _appendLog(fallbackBody, delivered: true, channel: 'server');
          return KakaoAlimtalkSendResult(
            delivered: body['delivered'] as bool? ?? true,
            channel: body['channel'] as String? ?? 'kakao_alimtalk',
            message: fallbackBody,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Kakao alimtalk server error: $e');
        }
      }
    }

    await _appendLog(fallbackBody, delivered: false, channel: 'local_queue');
    return KakaoAlimtalkSendResult(
      delivered: false,
      channel: 'local_queue',
      message: fallbackBody,
    );
  }

  Future<void> _appendLog(
    String body, {
    required bool delivered,
    required String channel,
  }) async {
    final raw = _prefs.getStringList(_logKey) ?? [];
    final entry =
        '${DateTime.now().toIso8601String()}|$channel|${delivered ? 'ok' : 'queued'}|$body';
    raw.insert(0, entry);
    await _prefs.setStringList(_logKey, raw.take(30).toList());
  }
}

class KakaoAlimtalkSendResult {
  const KakaoAlimtalkSendResult({
    required this.delivered,
    required this.channel,
    required this.message,
  });

  final bool delivered;
  final String channel;
  final String message;
}

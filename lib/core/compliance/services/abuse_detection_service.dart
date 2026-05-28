import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

/// 푸시-연락-매칭 이상 패턴 감지 (MVP)
class AbuseDetectionService {
  AbuseDetectionService({ComplianceRepository? repository})
      : _repository = repository;

  ComplianceRepository? _repository;

  Future<ComplianceRepository> _repo() async =>
      _repository ??= await ComplianceRepository.create();

  Future<List<AbuseAlert>> analyzeApplications(
    List<HiringApplication> applications, {
    required String companyKey,
  }) async {
    final alerts = <AbuseAlert>[];
    final companyApps =
        applications.where((a) => a.companyKey == companyKey).toList();

    final chatNoSchedule = companyApps.where(
      (a) =>
          a.status == HiringApplicationStatus.chatting &&
          DateTime.now().difference(a.appliedAt).inDays >= 3,
    );
    if (chatNoSchedule.isNotEmpty) {
      alerts.add(AbuseAlert(
        type: AbuseAlertType.chatWithoutSchedule,
        message:
            '채팅만 ${chatNoSchedule.length}건, 출근 예정 전환 없음 — 오프플랫폼 유도 의심',
        severity: AbuseSeverity.medium,
        applicationIds: chatNoSchedule.map((a) => a.id).toList(),
      ));
    }

    final scheduledNoCheckIn = companyApps.where(
      (a) =>
          a.status == HiringApplicationStatus.scheduled &&
          a.workDate != null &&
          DateTime.now().isAfter(a.workDate!.add(const Duration(days: 1))),
    );
    if (scheduledNoCheckIn.isNotEmpty) {
      alerts.add(AbuseAlert(
        type: AbuseAlertType.scheduledNoCheckIn,
        message:
            '출근 예정 ${scheduledNoCheckIn.length}건 — 출근 미확인(회피) 패턴',
        severity: AbuseSeverity.high,
        applicationIds: scheduledNoCheckIn.map((a) => a.id).toList(),
      ));
    }

    final checkedInUnpaid = companyApps.where((a) => a.needsCommissionPayment);
    if (checkedInUnpaid.isNotEmpty) {
      alerts.add(AbuseAlert(
        type: AbuseAlertType.unpaidCommission,
        message: '출근 확인 후 수수료 미결제 ${checkedInUnpaid.length}건',
        severity: AbuseSeverity.high,
        applicationIds: checkedInUnpaid.map((a) => a.id).toList(),
      ));
    }

    if (alerts.isNotEmpty) {
      final repo = await _repo();
      for (final alert in alerts) {
        await repo.addAbuseFlag({
          'type': alert.type.name,
          'message': alert.message,
          'severity': alert.severity.name,
          'companyKey': companyKey,
          'applicationIds': alert.applicationIds,
        });
      }
    }
    return alerts;
  }
}

enum AbuseAlertType {
  chatWithoutSchedule,
  scheduledNoCheckIn,
  unpaidCommission,
  offPlatformContact,
  industryFlag,
}

enum AbuseSeverity { low, medium, high, critical }

class AbuseAlert {
  const AbuseAlert({
    required this.type,
    required this.message,
    required this.severity,
    required this.applicationIds,
  });

  final AbuseAlertType type;
  final String message;
  final AbuseSeverity severity;
  final List<String> applicationIds;
}

/// 채팅 메시지 연락처·오프플랫폼 유도 필터
abstract final class ChatContactFilter {
  static final _phonePattern = RegExp(
    r'(\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4})|(\d{10,11})',
  );
  static final _kakaoPattern = RegExp(r'카카오|kakao|오픈채팅|open\.kakao', caseSensitive: false);
  static final _urlPattern = RegExp(r'https?://|www\.', caseSensitive: false);

  static String? validateOutbound(String text) {
    if (_phonePattern.hasMatch(text)) {
      return '전화번호는 파트너십 가입·출근 확정 후 공개됩니다.';
    }
    if (_kakaoPattern.hasMatch(text)) {
      return '외부 메신저 유도는 제한됩니다. 플랫폼 내 채팅을 이용해 주세요.';
    }
    if (_urlPattern.hasMatch(text)) {
      return '외부 링크 공유는 제한됩니다.';
    }
    return null;
  }
}

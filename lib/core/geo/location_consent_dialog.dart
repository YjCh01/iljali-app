import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/geo/location_consent_service.dart';

enum LocationConsentDialogAction {
  cancelled,
  agreeAndContinue,
  openSettings,
  openLocationSettings,
}

/// 위치기반서비스 이용 동의 + 기기 권한 안내
class LocationConsentDialog extends StatelessWidget {
  const LocationConsentDialog({
    super.key,
    required this.trigger,
    required this.status,
  });

  final LocationConsentTrigger trigger;
  final LocationAccessStatus status;

  static Future<LocationConsentDialogAction> show(
    BuildContext context, {
    required LocationConsentTrigger trigger,
    required LocationAccessStatus status,
  }) async {
    final result = await showDialog<LocationConsentDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationConsentDialog(
        trigger: trigger,
        status: status,
      ),
    );
    return result ?? LocationConsentDialogAction.cancelled;
  }

  String get _title => switch (trigger) {
        LocationConsentTrigger.signup => '위치정보 이용 동의',
        LocationConsentTrigger.checkIn => '출근 확인 — 위치 권한 필요',
        LocationConsentTrigger.mapBrowse => '지도 — 위치 권한 필요',
      };

  String get _body {
    final base = switch (trigger) {
      LocationConsentTrigger.signup =>
        '실주소 기반 공고 탐색·출근 확인을 위해 위치정보를 이용합니다.',
      LocationConsentTrigger.checkIn =>
        '출근 확인을 위해 현재 위치와 근무지 거리를 확인합니다.\n'
            '가입 시 동의하셨더라도, 기기에서 위치가 꺼져 있거나 권한이 없으면 다시 허용해 주세요.',
      LocationConsentTrigger.mapBrowse =>
        '내 주소·현재 위치 기반 지도 탐색을 위해 위치 권한이 필요합니다.',
    };
    if (status.blockingReason.isEmpty) return base;
    return '$base\n\n${status.blockingReason}';
  }

  @override
  Widget build(BuildContext context) {
    final needsConsent = !status.inAppConsentGranted;
    final needsGps = !status.locationServicesEnabled;
    final needsPermission = !status.devicePermissionGranted;

    return AlertDialog(
      title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_body, style: const TextStyle(height: 1.45, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.legalDocuments,
                arguments: const {'initialDocumentId': 'location'},
              ),
              child: const Text('위치기반서비스 이용약관 보기'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            LocationConsentDialogAction.cancelled,
          ),
          child: const Text('취소'),
        ),
        if (needsGps)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              LocationConsentDialogAction.openLocationSettings,
            ),
            child: const Text('GPS 설정'),
          ),
        if (needsPermission && !needsConsent)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              LocationConsentDialogAction.openSettings,
            ),
            child: const Text('앱 권한 설정'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            needsConsent
                ? LocationConsentDialogAction.agreeAndContinue
                : LocationConsentDialogAction.agreeAndContinue,
          ),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(needsConsent ? '동의하고 계속' : '다시 확인'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/location_consent_dialog.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 위치기반서비스 이용 동의 + 기기 위치 권한·GPS 상태
enum LocationConsentTrigger {
  signup,
  checkIn,
  mapBrowse,
}

class LocationAccessStatus {
  const LocationAccessStatus({
    required this.inAppConsentGranted,
    required this.devicePermissionGranted,
    required this.locationServicesEnabled,
  });

  final bool inAppConsentGranted;
  final bool devicePermissionGranted;
  final bool locationServicesEnabled;

  bool get isFullyGranted =>
      inAppConsentGranted &&
      devicePermissionGranted &&
      locationServicesEnabled;

  String get blockingReason {
    if (!inAppConsentGranted) {
      return '위치기반서비스 이용에 동의해 주세요.';
    }
    if (!locationServicesEnabled) {
      return '기기의 위치 서비스(GPS)가 꺼져 있습니다. 설정에서 켜 주세요.';
    }
    if (!devicePermissionGranted) {
      return '앱의 위치 접근 권한이 필요합니다.';
    }
    return '';
  }
}

abstract final class LocationConsentService {
  static Future<LocationAccessStatus> evaluate({
    bool? signupInAppConsent,
  }) async {
    final profile = AuthSession.instance.currentUser?.seekerProfile;
    final inApp = signupInAppConsent ??
        _isInAppConsentCurrent(profile);

    if (DeviceLocationService.allowsRelaxedLocation) {
      return LocationAccessStatus(
        inAppConsentGranted: inApp,
        devicePermissionGranted: true,
        locationServicesEnabled: true,
      );
    }

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    final deviceGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    return LocationAccessStatus(
      inAppConsentGranted: inApp,
      devicePermissionGranted: deviceGranted,
      locationServicesEnabled: servicesEnabled,
    );
  }

  static bool _isInAppConsentCurrent(SeekerMemberProfile? profile) {
    if (profile == null) return false;
    return profile.locationConsentAcceptedAt != null &&
        profile.locationConsentVersion ==
            LegalConsentCatalog.locationBasedVersion;
  }

  /// 가입·출근체크 등 — 앱 동의 + 기기 권한·GPS를 매번 재확인
  static Future<bool> ensureGranted(
    BuildContext context, {
    required LocationConsentTrigger trigger,
    bool signupInAppConsent = false,
  }) async {
    var signupConsent = signupInAppConsent;
    while (context.mounted) {
      final status = await evaluate(
        signupInAppConsent:
            trigger == LocationConsentTrigger.signup ? signupConsent : null,
      );
      if (status.isFullyGranted) {
        if (trigger != LocationConsentTrigger.signup) {
          await _persistConsent();
        }
        return true;
      }

      final action = await LocationConsentDialog.show(
        context,
        trigger: trigger,
        status: status,
      );
      if (!context.mounted) return false;

      switch (action) {
        case LocationConsentDialogAction.cancelled:
          return false;
        case LocationConsentDialogAction.openSettings:
          await Geolocator.openAppSettings();
          continue;
        case LocationConsentDialogAction.openLocationSettings:
          await Geolocator.openLocationSettings();
          continue;
        case LocationConsentDialogAction.agreeAndContinue:
          if (trigger == LocationConsentTrigger.signup) {
            signupConsent = true;
          } else {
            await _persistConsent();
          }
          if (!DeviceLocationService.allowsRelaxedLocation) {
            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
          }
          continue;
      }
    }
    return false;
  }

  static Future<void> _persistConsent() async {
    final user = AuthSession.instance.currentUser;
    if (user == null || !user.isIndividual) return;
    final seeker = user.seekerProfile ?? const SeekerMemberProfile(phoneVerified: true);
    await AuthSession.instance.updateSeekerProfile(
      seeker.copyWith(
        locationConsentAcceptedAt: DateTime.now(),
        locationConsentVersion: LegalConsentCatalog.locationBasedVersion,
      ),
    );
  }

  /// 가입 완료 시 프로필에 동의 시각 기록
  static SeekerMemberProfile applySignupConsent(SeekerMemberProfile profile) {
    return profile.copyWith(
      locationConsentAcceptedAt: DateTime.now(),
      locationConsentVersion: LegalConsentCatalog.locationBasedVersion,
    );
  }
}

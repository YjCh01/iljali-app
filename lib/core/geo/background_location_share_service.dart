import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 버스위치 공유 담당(어드민 지정자) 전용 — 화면이 꺼지거나 백그라운드로 가도
/// 셔틀 위치를 계속 전송하기 위한 위치 스트림.
abstract final class BackgroundLocationShareService {
  static StreamSubscription<Position>? _subscription;

  static bool get isSharing => _subscription != null;

  /// Google Play "Prominent Disclosure" 요건 — 시스템 권한창을 띄우기 전에
  /// 왜 백그라운드 위치가 필요한지 앱 안에서 먼저 명확히 안내한다.
  static Future<bool> requestAlwaysPermission(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('백그라운드 위치 권한 안내'),
        content: const Text(
          '버스위치 공유 담당으로 지정되면, 화면을 끄거나 다른 앱을 사용 중에도 '
          '같은 셔틀 탑승자에게 실시간 위치를 계속 전달합니다.\n\n'
          '다음 화면에서 "항상 허용"을 선택해 주세요. 위치 공유는 언제든 '
          '"위치 공유 중지" 버튼으로 즉시 끌 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('계속하기'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return false;

    var whileInUse = await Geolocator.checkPermission();
    if (whileInUse == LocationPermission.denied) {
      whileInUse = await Geolocator.requestPermission();
    }
    if (whileInUse == LocationPermission.denied ||
        whileInUse == LocationPermission.deniedForever) {
      return false;
    }
    if (whileInUse == LocationPermission.always) {
      return true;
    }

    final alwaysStatus = await Permission.locationAlways.request();
    return alwaysStatus.isGranted;
  }

  static Future<bool> hasAlwaysPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// 백그라운드 스트림 시작 — [onPosition]은 위치가 갱신될 때마다 호출된다.
  static Future<bool> startSharing({
    required void Function(Position position) onPosition,
    required void Function(Object error) onError,
  }) async {
    if (_subscription != null) return true;
    if (!await hasAlwaysPermission()) return false;

    final LocationSettings settings;
    if (!kIsWeb && Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 12),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '셔틀 위치 공유 중',
          notificationText: '탑승자에게 실시간 위치를 전달하고 있습니다.',
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(onPosition, onError: onError);
    return true;
  }

  static Future<void> stopSharing() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

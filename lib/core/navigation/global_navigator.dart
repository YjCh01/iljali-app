import 'package:flutter/material.dart';

/// 앱 전역 Navigator — FCM 알림 탭 등 위젯 트리 바깥에서 라우팅이 필요할 때 사용.
final navigatorKey = GlobalKey<NavigatorState>();

/// 앱 전역 ScaffoldMessenger — 포그라운드 푸시 수신 시 스낵바 표시용.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

import 'package:flutter/foundation.dart';

/// 포그라운드에서 새 지원자 푸시 수신 시 증가하는 신호 — 홈 셸이 구독해
/// 하단탭 배지·스낵바를 갱신한다.
abstract final class CorporateNewApplicantSignal {
  static final ValueNotifier<int> ping = ValueNotifier<int>(0);

  static void notify() {
    ping.value++;
  }
}

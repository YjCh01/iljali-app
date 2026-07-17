import 'package:flutter/foundation.dart';

/// 포그라운드에서 근무확정·면접확정 푸시 수신 시 증가하는 신호 — 구직자 홈 셸이
/// 구독해 "내일자리" 탭 배지·스낵바를 갱신한다.
abstract final class SeekerApplicationUpdateSignal {
  static final ValueNotifier<int> ping = ValueNotifier<int>(0);

  static void notify() {
    ping.value++;
  }
}

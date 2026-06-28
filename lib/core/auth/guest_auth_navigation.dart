import 'package:flutter/material.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/guest_browse_intent.dart';
import 'package:map/core/session/member_type.dart';

/// 비로그인 — 맵 둘러보기 후 로그인/가입 (통합 iljari.app: 게이트웨이 → 유형 선택)
abstract final class GuestAuthNavigation {
  /// 통합 실서비스 — 맵 먼저, 로그인 시 개인/기업 선택
  static bool get usesMemberGateway =>
      !EnvConfig.individualEntry &&
      !EnvConfig.isCorporateBrowseEntry &&
      !EnvConfig.adminEntry;

  static void openLogin(BuildContext context) {
    if (usesMemberGateway) {
      Navigator.of(context).pushNamed(AppRoutes.memberGateway);
      return;
    }
    final memberType = GuestBrowseIntent.mode == GuestBrowseMode.corporate
        ? MemberType.corporate
        : MemberType.individual;
    Navigator.of(context).pushNamed(AppRoutes.login, arguments: memberType);
  }

  static void openSignUp(BuildContext context) {
    if (usesMemberGateway) {
      Navigator.of(context).pushNamed(AppRoutes.memberGateway);
      return;
    }
    final memberType = GuestBrowseIntent.mode == GuestBrowseMode.corporate
        ? MemberType.corporate
        : MemberType.individual;
    Navigator.of(context).pushNamed(AppRoutes.signUp, arguments: memberType);
  }
}

import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';

/// 기업 셸 — 홈(지도)·더보기는 비회원 허용
abstract final class CorporateShellAccess {
  static const homeTabIndex = 0;
  static const moreTabIndex = 5;

  static bool get isSignedInCorporate {
    final user = AuthSession.instance.currentUser;
    return user != null && user.memberType == MemberType.corporate;
  }

  static bool isTabEnabled(int index) =>
      index == homeTabIndex ||
      index == moreTabIndex ||
      isSignedInCorporate;
}

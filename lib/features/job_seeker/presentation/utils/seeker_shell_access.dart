import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';

/// 구직자 셸 — 지도·더보기는 비회원 허용, 지원·보관함·채팅은 로그인 필요
abstract final class SeekerShellAccess {
  static const mapTabIndex = 0;
  static const moreTabIndex = 4;

  static bool get isSignedInSeeker {
    final user = AuthSession.instance.currentUser;
    return user != null && user.memberType == MemberType.individual;
  }

  static bool isTabEnabled(int index) =>
      index == mapTabIndex ||
      index == moreTabIndex ||
      isSignedInSeeker;
}

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

/// 기업 지도 — 모든 기업회원이 타사 공고·셔틀 노선 열람 가능
abstract final class CorporateMapContentAccessPolicy {
  static bool hasPaidIntelAccess(CorporateMemberProfile? profile) {
    if (profile == null) return false;
    if (profile.hasLegacyPaidSubscription) return true;
    return _walletUnlocksIntel(profile.pushWallet);
  }

  static bool _walletUnlocksIntel(EmployerPushWallet? wallet) {
    if (wallet == null) return false;
    return wallet.lifetimePackagesPurchased > 0 ||
        wallet.packageCredits > 0 ||
        wallet.exposurePushBundleCredits > 0 ||
        wallet.pushTicketCredits > 0 ||
        wallet.locationSlotsFromPackages > 0;
  }

  static bool isOwnPost({
    required Set<String> ownPostIds,
    required String postId,
  }) =>
      ownPostIds.contains(postId);

  static bool canViewPostContent({
    required CorporateMemberProfile? viewerProfile,
    required Set<String> ownPostIds,
    required CorporateJobPost post,
  }) =>
      true;

  static bool canViewShuttleContent({
    required CorporateMemberProfile? viewerProfile,
    required String routeCompanyKey,
  }) =>
      true;
}

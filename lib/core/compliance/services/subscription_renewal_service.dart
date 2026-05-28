import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// Legacy subscription expiry — loads wallet; tier stored in profile for JSON only.
class SubscriptionRenewalService {
  static const subscriptionPeriodDays = 30;

  Future<SubscriptionRenewalResult> checkAndApplyExpiry() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      return const SubscriptionRenewalResult(checked: true, changed: false);
    }

    final wallet = await PushWalletService().loadWallet(profile);
    if (profile.pushWallet == null) {
      await AuthSession.instance.updateCorporateProfile(
        profile.copyWith(pushWallet: wallet),
      );
    }
    return const SubscriptionRenewalResult(checked: true, changed: false);
  }

  static DateTime defaultExpiryFromNow() =>
      DateTime.now().add(const Duration(days: subscriptionPeriodDays));
}

class SubscriptionRenewalResult {
  const SubscriptionRenewalResult({
    required this.checked,
    required this.changed,
    this.expired = false,
    this.daysUntilExpiry,
    this.expiresAt,
    this.previousTier,
  });

  final bool checked;
  final bool changed;
  final bool expired;
  final int? daysUntilExpiry;
  final DateTime? expiresAt;
  final dynamic previousTier;
}

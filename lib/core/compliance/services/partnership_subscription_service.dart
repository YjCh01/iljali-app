import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

class PartnershipSubscriptionResult {
  const PartnershipSubscriptionResult({
    required this.success,
    required this.tier,
    this.transactionId,
    this.message,
    this.enterpriseInquirySubmitted = false,
  });

  final bool success;
  final PremiumPartnershipTier tier;
  final String? transactionId;
  final String? message;
  final bool enterpriseInquirySubmitted;
}

/// @deprecated Legacy — use [PushPackagePurchaseService].
class PartnershipSubscriptionService {
  PartnershipSubscriptionService({ComplianceApiClient? apiClient});

  int listPrice(PremiumPartnershipTier tier) =>
      PushPackageCatalog.singlePackagePriceKrw;

  Future<PartnershipSubscriptionResult> switchToBasic({
    required CorporateMemberProfile profile,
    bool agreedToTerms = true,
  }) async {
    final wallet = await PushWalletService().loadWallet(profile);
    await AuthSession.instance.updateCorporateProfile(
      profile.copyWith(
        partnershipTier: PremiumPartnershipTier.basic,
        monthlySubscriptionActive: false,
        clearSubscriptionExpiresAt: true,
        pushWallet: wallet,
      ),
    );
    return const PartnershipSubscriptionResult(
      success: true,
      tier: PremiumPartnershipTier.basic,
      message: '기본 플랜을 이용 중입니다.',
    );
  }
}

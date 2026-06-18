import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_org_member.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_delegate_info.dart';
import 'package:map/features/corporate/domain/services/commission_payer_resolver.dart';

/// 결제 권한·위임 관계 판단
class CorporatePaymentAccessService {
  CorporatePaymentAccessService({
    CorporateOrganizationRepository? orgRepository,
    CommissionPayerResolver? payerResolver,
  })  : _orgRepository = orgRepository,
        _payerResolver = payerResolver;

  CorporateOrganizationRepository? _orgRepository;
  CommissionPayerResolver? _payerResolver;

  Future<CorporateOrganizationRepository> _org() async =>
      _orgRepository ??= await CorporateOrganizationRepository.create();

  Future<CommissionPayerResolver> _resolver() async =>
      _payerResolver ??= await CommissionPayerResolver.create();

  Future<bool> isPaymentAuthority({
    required String companyKey,
    required String email,
  }) async {
    final member = await (await _org()).findMember(
      companyKey: companyKey,
      email: email,
    );
    return member?.isPaymentAuthority ?? false;
  }

  Future<List<CorporateOrgMember>> listPaymentAuthorities(
    String companyKey,
  ) async {
    final members = await (await _org()).listMembers(companyKey);
    return members.where((m) => m.isPaymentAuthority).toList();
  }

  /// 채용 담당자의 결제 요청 수신자 — 위임 결제권자 → 없으면 첫 결제권한자
  Future<String?> resolvePayerEmail({
    required String companyKey,
    required String requesterEmail,
  }) async {
    final delegated = await (await _resolver()).resolvePayerEmail(
      companyKey: companyKey,
      recruiterEmail: requesterEmail,
    );
    final requester = requesterEmail.trim().toLowerCase();
    if (delegated.trim().isNotEmpty &&
        delegated.trim().toLowerCase() != requester) {
      final member = await (await _org()).findMember(
        companyKey: companyKey,
        email: delegated,
      );
      if (member?.isPaymentAuthority == true) return delegated.trim();
    }

    final authorities = await listPaymentAuthorities(companyKey);
    if (authorities.isEmpty) return null;
    return authorities.first.email.trim();
  }

  Future<bool> canPayDirectly({
    required String companyKey,
    required String email,
  }) async {
    return isPaymentAuthority(companyKey: companyKey, email: email);
  }

  Future<bool> shouldUsePaymentRequest({
    required String companyKey,
    required String email,
  }) async {
    if (await canPayDirectly(companyKey: companyKey, email: email)) {
      return false;
    }
    final payer = await resolvePayerEmail(
      companyKey: companyKey,
      requesterEmail: email,
    );
    return payer != null && payer.trim().isNotEmpty;
  }

  Future<CorporatePaymentDelegateInfo> loadDelegateInfo({
    required String companyKey,
    required String email,
  }) async {
    final isAuthority = await isPaymentAuthority(
      companyKey: companyKey,
      email: email,
    );
    final payerEmail = await resolvePayerEmail(
      companyKey: companyKey,
      requesterEmail: email,
    );
    CorporateOrgMember? payerMember;
    if (payerEmail != null) {
      payerMember = await (await _org()).findMember(
        companyKey: companyKey,
        email: payerEmail,
      );
    }
    final delegations = await (await _org()).listDelegations(companyKey);
    final normalized = email.trim().toLowerCase();
    final hasDelegation = delegations.any(
      (d) =>
          d.isActive &&
          d.recruiterEmail.trim().toLowerCase() == normalized &&
          d.payerEmail.trim().toLowerCase() ==
              (payerEmail ?? '').trim().toLowerCase(),
    );
    return CorporatePaymentDelegateInfo(
      isPaymentAuthority: isAuthority,
      // 결제 요청 UI·플로우는 관리자 위임이 수락된 경우에만
      canRequestPayment: !isAuthority &&
          hasDelegation &&
          (payerEmail?.isNotEmpty ?? false),
      payerEmail: payerEmail,
      payerDisplayName: payerMember?.displayLabel,
      hasAcceptedDelegation: hasDelegation,
    );
  }
}

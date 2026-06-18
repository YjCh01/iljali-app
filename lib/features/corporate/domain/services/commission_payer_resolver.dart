import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';

/// 채용 수수료 결제 담당자 이메일 결정
class CommissionPayerResolver {
  const CommissionPayerResolver(this._orgRepo);

  final CorporateOrganizationRepository _orgRepo;

  static Future<CommissionPayerResolver> create() async {
    final repo = await CorporateOrganizationRepository.create();
    return CommissionPayerResolver(repo);
  }

  /// 위임된 결제 권한자 → 없으면 채용 담당자(공고 등록자) 본인
  Future<String> resolvePayerEmail({
    required String? companyKey,
    required String? recruiterEmail,
  }) async {
    final recruiter = recruiterEmail?.trim();
    if (recruiter != null && recruiter.isNotEmpty) {
      final key = companyKey?.trim();
      if (key != null && key.isNotEmpty) {
        final delegated = await _orgRepo.findAcceptedPayer(
          companyKey: key,
          recruiterEmail: recruiter,
        );
        if (delegated != null && delegated.trim().isNotEmpty) {
          return delegated.trim();
        }
      }
      return recruiter;
    }
    return recruiter ?? '';
  }

  Future<bool> isPayerForApplication({
    required String viewerEmail,
    required String? companyKey,
    required String? recruiterEmail,
  }) async {
    final payer = await resolvePayerEmail(
      companyKey: companyKey,
      recruiterEmail: recruiterEmail,
    );
    if (payer.isEmpty) return true;
    return payer.trim().toLowerCase() == viewerEmail.trim().toLowerCase();
  }
}

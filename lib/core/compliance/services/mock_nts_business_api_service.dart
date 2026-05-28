/// 국세청/공공데이터 사업자 상태 조회 결과 (MVP mock)
class NtsBusinessLookupResult {
  const NtsBusinessLookupResult({
    required this.valid,
    required this.companyName,
    required this.industryName,
    required this.businessStatus,
    required this.entityTypeLabel,
    this.apiSource = 'mock_nts',
  });

  final bool valid;
  final String companyName;
  final String industryName;
  final String businessStatus;
  final String entityTypeLabel;
  final String apiSource;
}

abstract class NtsBusinessApiService {
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  });
}

/// MVP mock — 실서비스: 국세청 사업자등록 상태조회 API / 공공데이터포털
class MockNtsBusinessApiService implements NtsBusinessApiService {
  const MockNtsBusinessApiService();

  @override
  Future<NtsBusinessLookupResult> verifyBusiness({
    required String businessRegistrationNumber,
    required String companyName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final brn = businessRegistrationNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (brn.length != 10) {
      return const NtsBusinessLookupResult(
        valid: false,
        companyName: '',
        industryName: '',
        businessStatus: 'invalid',
        entityTypeLabel: '',
      );
    }
    final isOutsourcing = brn.endsWith('9999');
    final isCorp = brn.startsWith('1') || brn.startsWith('2');
    return NtsBusinessLookupResult(
      valid: true,
      companyName: companyName,
      industryName: isOutsourcing ? '인력공급업' : '화물운송 및 물류대행',
      businessStatus: 'continuing',
      entityTypeLabel: isCorp ? '법인' : '개인사업자',
    );
  }
}

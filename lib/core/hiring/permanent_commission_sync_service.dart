import 'package:map/core/hiring/data/permanent_commission_api_client.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/local_permanent_employment_repository.dart';
import 'package:map/core/hiring/monthly_commission.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';

/// 상시직 채용·인증·수수료 — 서버 동기화 (MVP: push on write, pull on start)
class PermanentCommissionSyncService {
  PermanentCommissionSyncService({PermanentCommissionApiClient? apiClient})
      : _api = apiClient ?? PermanentCommissionApiClient();

  final PermanentCommissionApiClient _api;

  Future<void> pushEmployment(PermanentEmploymentRecord record) async {
    if (!_api.isEnabled) return;
    try {
      await _api.registerEmployment(record);
    } on PermanentCommissionApiException {
      // MVP: 로컬 우선 — 동기화 실패는 무시
    }
  }

  Future<void> pushVerification(InsuranceVerificationLog log) async {
    if (!_api.isEnabled) return;
    try {
      await _api.saveInsuranceVerification(log);
    } on PermanentCommissionApiException {
      // ignore
    }
  }

  Future<void> pushCommission(MonthlyCommission commission) async {
    if (!_api.isEnabled) return;
    try {
      await _api.saveMonthlyCommission(commission);
    } on PermanentCommissionApiException {
      // ignore
    }
  }

  Future<void> pullForCompany({
    required String companyKey,
    required String companyName,
  }) async {
    if (!_api.isEnabled) return;

    try {
      final remote = await _api.listEmployments(companyKey);
      if (remote.isEmpty) return;

      final repo = await LocalPermanentEmploymentRepository.create();
      await repo.mergeRemoteEmployments(
        companyKey: companyKey,
        companyName: companyName,
        remote: remote
            .map(
              (item) => (
                employmentId: item.employmentId,
                seekerName: item.seekerName,
                monthlySalaryKrw: item.monthlySalaryKrw,
                hireDate: item.hireDate,
              ),
            )
            .toList(),
      );
    } on PermanentCommissionApiException {
      // ignore
    }
  }
}

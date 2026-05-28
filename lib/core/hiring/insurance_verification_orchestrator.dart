import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/data/insurance_auth_api_client.dart';
import 'package:map/core/hiring/insurance_auth_provider.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/insurance_verification_service.dart';

class InsuranceVerificationOrchestratorResult {
  const InsuranceVerificationOrchestratorResult({
    required this.success,
    required this.log,
    this.message,
    this.usedRemoteApi = false,
  });

  final bool success;
  final InsuranceVerificationLog log;
  final String? message;
  final bool usedRemoteApi;
}

/// 로컬 mock vs 서버 CODEF/Barocert 연동 분기
class InsuranceVerificationOrchestrator {
  InsuranceVerificationOrchestrator({
    InsuranceAuthApiClient? apiClient,
    InsuranceVerificationService? localService,
  })  : _api = apiClient ?? InsuranceAuthApiClient(),
        _local = localService ?? InsuranceVerificationService();

  final InsuranceAuthApiClient _api;
  final InsuranceVerificationService _local;

  bool get isRemoteEnabled =>
      EnvConfig.isComplianceApiEnabled && _api.isEnabled;

  Future<AuthSessionStart> startSimpleAuth({
    required String employmentId,
    required String seekerEmail,
    required InsuranceAuthProvider provider,
  }) async {
    if (!isRemoteEnabled) {
      return AuthSessionStart(
        sessionId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        authProvider: provider.apiValue,
        authBackend: 'local',
        status: 'pending',
        mockCompleteAvailable: true,
      );
    }
    return _api.startSession(
      employmentId: employmentId,
      seekerEmail: seekerEmail,
      provider: provider,
    );
  }

  Future<InsuranceVerificationOrchestratorResult> completeVerification({
    required String employmentId,
    required String employerCompanyName,
    required String seekerEmail,
    required InsuranceAuthProvider provider,
    required String sessionId,
    String? workplaceNameFallback,
    bool currentlyEmployedFallback = true,
    bool mockSession = false,
  }) async {
    final now = DateTime.now();

    if (isRemoteEnabled && !sessionId.startsWith('local_')) {
      final result = await _api.completeSession(
        sessionId: sessionId,
        mockCi: mockSession ? 'CI-$seekerEmail' : null,
      );
      final log = result.toLog(
        employmentId: employmentId,
        employerCompanyName: employerCompanyName,
      );
      return InsuranceVerificationOrchestratorResult(
        success: result.success,
        log: log,
        message: result.success
            ? '건강보험 재직 인증이 완료되었습니다.'
            : result.rejectionReason,
        usedRemoteApi: true,
      );
    }

    // 로컬 MVP — 수동 입력 fallback
    final localResult = _local.verify(
      employmentId: employmentId,
      employerCompanyName: employerCompanyName,
      workplaceNameFromCertificate:
          workplaceNameFallback ?? employerCompanyName,
      currentlyEmployed: currentlyEmployedFallback,
      now: now,
    );
    return InsuranceVerificationOrchestratorResult(
      success: localResult.success,
      log: localResult.log.copyWith(
        authProvider: provider.apiValue,
        method: '${provider.apiValue}_simple_auth',
      ),
      message: localResult.message,
      usedRemoteApi: false,
    );
  }

  Future<List<RemoteVerificationSummary>> fetchRemoteHistory(
    String employmentId,
  ) async {
    if (!isRemoteEnabled) return [];
    return _api.listVerifications(employmentId);
  }

  Future<VerificationApiResult?> attemptAutoReverify({
    required String employmentId,
    required int cycleNumber,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    if (!isRemoteEnabled) return null;
    try {
      return await _api.reverify(
        employmentId: employmentId,
        cycleNumber: cycleNumber,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    } catch (_) {
      return null;
    }
  }
}

extension InsuranceVerificationLogCopy on InsuranceVerificationLog {
  InsuranceVerificationLog copyWith({
    String? method,
    String? authProvider,
    String? certificateProvider,
    int? cycleNumber,
    String? simpleAuthSessionId,
    String? ciHash,
  }) {
    return InsuranceVerificationLog(
      id: id,
      employmentId: employmentId,
      workplaceName: workplaceName,
      employerCompanyName: employerCompanyName,
      companyNameMatched: companyNameMatched,
      employedConfirmed: employedConfirmed,
      verifiedAt: verifiedAt,
      expiresAt: expiresAt,
      status: status,
      method: method ?? this.method,
      rejectionReason: rejectionReason,
      authProvider: authProvider ?? this.authProvider,
      certificateProvider: certificateProvider ?? this.certificateProvider,
      cycleNumber: cycleNumber ?? this.cycleNumber,
      simpleAuthSessionId: simpleAuthSessionId ?? this.simpleAuthSessionId,
      ciHash: ciHash ?? this.ciHash,
    );
  }
}

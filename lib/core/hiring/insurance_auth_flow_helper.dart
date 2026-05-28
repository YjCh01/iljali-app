import 'package:flutter/material.dart';
import 'package:map/core/hiring/data/insurance_auth_api_client.dart';
import 'package:map/core/hiring/insurance_auth_provider.dart';
import 'package:map/core/hiring/insurance_verification_log.dart';
import 'package:map/core/hiring/insurance_verification_orchestrator.dart';
import 'package:map/features/job_seeker/presentation/pages/insurance_auth_checkout_page.dart';

/// 간편인증 → WebView → 자격득실 조회 → 검증
class InsuranceAuthFlowHelper {
  InsuranceAuthFlowHelper({InsuranceVerificationOrchestrator? orchestrator})
      : _orchestrator = orchestrator ?? InsuranceVerificationOrchestrator();

  final InsuranceVerificationOrchestrator _orchestrator;

  bool get isRemoteEnabled => _orchestrator.isRemoteEnabled;

  Future<InsuranceVerificationOrchestratorResult> run({
    required BuildContext context,
    required String employmentId,
    required String employerCompanyName,
    required String seekerEmail,
    required InsuranceAuthProvider provider,
    String? workplaceNameFallback,
    bool currentlyEmployedFallback = true,
  }) async {
    final session = await _orchestrator.startSimpleAuth(
      employmentId: employmentId,
      seekerEmail: seekerEmail,
      provider: provider,
    );

    if (session.requiresWebview &&
        session.authUrl != null &&
        session.authUrl!.isNotEmpty) {
      if (!context.mounted) {
        throw StateError('context_unmounted');
      }

      final authOk = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => InsuranceAuthCheckoutPage(
            authUrl: session.authUrl!,
            sessionId: session.sessionId,
          ),
        ),
      );

      if (authOk != true) {
        return InsuranceVerificationOrchestratorResult(
          success: false,
          log: InsuranceVerificationLog(
            id: 'cancel_${DateTime.now().millisecondsSinceEpoch}',
            employmentId: employmentId,
            workplaceName: '',
            employerCompanyName: employerCompanyName,
            companyNameMatched: false,
            employedConfirmed: false,
            verifiedAt: DateTime.now(),
            expiresAt: DateTime.now(),
            status: InsuranceVerificationStatus.rejected,
            rejectionReason: '간편인증이 취소되었습니다.',
          ),
          message: '간편인증이 취소되었습니다.',
          usedRemoteApi: true,
        );
      }

      await _pollSessionReady(session.sessionId);
    }

    return _orchestrator.completeVerification(
      employmentId: employmentId,
      employerCompanyName: employerCompanyName,
      seekerEmail: seekerEmail,
      provider: provider,
      sessionId: session.sessionId,
      workplaceNameFallback: workplaceNameFallback,
      currentlyEmployedFallback: currentlyEmployedFallback,
      mockSession: session.mockCompleteAvailable,
    );
  }

  Future<void> _pollSessionReady(String sessionId) async {
    final client = InsuranceAuthApiClient();
    for (var i = 0; i < 15; i++) {
      final status = await client.getSession(sessionId);
      if (status.authCompleted) return;
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  }
}

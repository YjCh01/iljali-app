import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/insurance_auth_provider.dart';
import 'package:map/core/hiring/insurance_verification_orchestrator.dart';
import 'package:map/core/hiring/insurance_verification_service.dart';

void main() {
  test('local orchestrator completes verification without API', () async {
    final orchestrator = InsuranceVerificationOrchestrator(
      localService: InsuranceVerificationService(),
    );

    final session = await orchestrator.startSimpleAuth(
      employmentId: 'perm_1',
      seekerEmail: 'worker@test.com',
      provider: InsuranceAuthProvider.naver,
    );

    expect(session.mockCompleteAvailable, isTrue);

    final result = await orchestrator.completeVerification(
      employmentId: 'perm_1',
      employerCompanyName: '(주)일자리',
      seekerEmail: 'worker@test.com',
      provider: InsuranceAuthProvider.naver,
      sessionId: session.sessionId,
      workplaceNameFallback: '주식회사 일자리',
    );

    expect(result.success, isTrue);
    expect(result.usedRemoteApi, isFalse);
    expect(result.log.authProvider, 'naver');
  });

  test('InsuranceAuthProvider labels', () {
    expect(InsuranceAuthProvider.naver.label, '네이버');
    expect(InsuranceAuthProvider.pass.label, 'PASS');
  });
}

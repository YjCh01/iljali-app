import 'package:map/features/corporate/domain/entities/payment_request.dart';

/// PG 결제 게이트웨이 인터페이스.
///
/// 실제 서비스에서는 토스페이먼츠·아임포트·KG이니시스 등 PG SDK/API를
/// 이 인터페이스 뒤에 구현합니다. 필요한 값은 보통:
/// - 가맹점 ID (MID / storeId)
/// - API Secret Key (서버 보관)
/// - 클라이언트 키 (앱/Web SDK용)
/// - 결제 성공/실패 redirect URL (Web)
/// - 웹훅 URL (서버에서 결제 검증)
abstract class PaymentGatewayService {
  Future<PaymentResult> requestPayment(PaymentRequest request);
}

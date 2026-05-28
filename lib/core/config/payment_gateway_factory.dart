import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/services/mock_payment_gateway_service.dart';
import 'package:map/features/corporate/data/services/remote_payments_gateway_service.dart';
import 'package:map/features/corporate/data/services/toss_payments_gateway_service.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';

/// 환경에 맞는 PG 게이트웨이 선택
abstract final class PaymentGatewayFactory {
  static PaymentGatewayService create() {
    if (EnvConfig.isComplianceApiEnabled) {
      return RemotePaymentsGatewayService();
    }
    if (EnvConfig.isTossPaymentsConfigured) {
      return TossPaymentsGatewayService();
    }
    return const MockPaymentGatewayService();
  }
}

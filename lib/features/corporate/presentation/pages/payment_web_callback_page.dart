import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/data/services/remote_payments_gateway_service.dart';

/// Toss 웹 결제 successUrl / failUrl 리다이렉트 처리 (staging·production)
class PaymentWebCallbackPage extends StatefulWidget {
  const PaymentWebCallbackPage({super.key, required this.success});

  final bool success;

  @override
  State<PaymentWebCallbackPage> createState() => _PaymentWebCallbackPageState();
}

class _PaymentWebCallbackPageState extends State<PaymentWebCallbackPage> {
  String _message = '결제 결과를 확인하는 중입니다…';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.success) {
      _confirmPayment();
    } else {
      setState(() {
        _message = '결제가 취소되었거나 실패했습니다.';
        _done = true;
      });
    }
  }

  Future<void> _confirmPayment() async {
    if (!kIsWeb) {
      setState(() {
        _message = '웹 전용 결제 콜백 페이지입니다.';
        _done = true;
      });
      return;
    }

    final params = Uri.base.queryParameters;
    final paymentKey = params['paymentKey'] ?? params['payment_key'] ?? '';
    final orderId = params['orderId'] ?? params['order_id'] ?? '';
    final amountRaw = params['amount'] ?? params['amount_krw'] ?? '0';
    final amount = int.tryParse(amountRaw) ?? 0;

    if (paymentKey.isEmpty || orderId.isEmpty || amount <= 0) {
      setState(() {
        _message = '결제 승인 정보가 올바르지 않습니다.';
        _done = true;
      });
      return;
    }

    if (!EnvConfig.isComplianceApiEnabled) {
      setState(() {
        _message = '결제 승인 완료 (API 미연결 — 로컬 확인만)';
        _done = true;
      });
      return;
    }

    final gateway = RemotePaymentsGatewayService();
    final result = await gateway.confirmViaServer(
      paymentKey: paymentKey,
      orderId: orderId,
      amountKrw: amount,
    );

    if (!mounted) return;
    setState(() {
      _message = result.success
          ? '결제가 완료되었습니다.'
          : (result.message ?? '결제 승인에 실패했습니다.');
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.success ? Icons.check_circle_outline : Icons.error_outline,
                size: 56,
                color: widget.success ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (_done) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (_) => false,
                  ),
                  child: const Text('앱으로 돌아가기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

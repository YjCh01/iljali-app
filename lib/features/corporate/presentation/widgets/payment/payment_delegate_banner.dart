import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_delegate_info.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';

/// A(채용 담당자) — 결제 위임 상태 배너
class PaymentDelegateBanner extends StatelessWidget {
  const PaymentDelegateBanner({
    super.key,
    required this.delegate,
    this.pendingRequests = const [],
    this.onCancelRequest,
  });

  final CorporatePaymentDelegateInfo delegate;
  final List<JobPostPaymentRequest> pendingRequests;
  final void Function(JobPostPaymentRequest request)? onCancelRequest;

  @override
  Widget build(BuildContext context) {
    if (delegate.isPaymentAuthority) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppColors.primary.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delegate.delegateBannerTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delegate.hasAcceptedDelegation
                            ? '공고 등록·핀 설정은 직접 하시고, '
                                '유료 노출·PUSH는 직접 결제하거나 담당자에게 요청할 수 있습니다.'
                            : '결제 권한자에게 요청하면 결제 관리 화면에서 바로 처리할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '보낸 결제 요청 ${pendingRequests.length}건',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 6),
              ...pendingRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '· ${request.productLabel} · '
                          '${_formatKrw(request.amountKrw)} · 대기 중',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      if (onCancelRequest != null)
                        TextButton(
                          onPressed: () => onCancelRequest!(request),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 28),
                          ),
                          child: const Text('취소', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatKrw(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}

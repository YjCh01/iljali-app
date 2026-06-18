import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 고객센터 — FAQ + 문의 이메일
class CustomerSupportPage extends StatelessWidget {
  const CustomerSupportPage({super.key});

  static const supportEmail = 'support@iljari.co.kr';

  static List<(String, String)> get _faqs => [
    (
      '공고 등록은 무료인가요?',
      '네. 기업회원은 공고 등록·수정이 무료입니다. '
          '주변 구직자에게 알리려면 일자리 알림핀(유료 패키지)을 사용합니다.',
    ),
    (
      '일자리 알림핀이란?',
      '근무지 기준 1km 반경으로 공고를 노출·PUSH하는 유료 상품입니다. '
          '가입 시 2회, 사업자 인증 완료 시 5회 보너스가 지급됩니다.',
    ),
    (
      '지원 후 채팅은 언제 열리나요?',
      '지원 직후 기업 담당자와 1:1 채팅이 연결됩니다. '
          '「내 지원」 탭에서 채팅하기로 들어갈 수 있습니다.',
    ),
    if (ProductFeatureFlags.isHiringCommissionEnabled)
      (
        '출근 확인·수수료는 어떻게 되나요?',
        '근무 예정일에 쌍방 출근 확인 후 일용직 수수료가 정산됩니다. '
            '퇴근 체크는 별도로 하지 않습니다.',
      )
    else
      (
        '출근 확인은 어떻게 되나요?',
        '근무 예정일에 기업과 구직자가 쌍방으로 출근을 확인합니다. '
            '확인이 완료되면 채용 기록이 마무리됩니다. 퇴근 체크는 별도로 하지 않습니다.',
      ),
    (
      '보관함 폴더는 어떻게 쓰나요?',
      '지도·공고 상세에서 「보관함에 저장」 후 폴더별로 정리할 수 있습니다. '
          '30일이 지나면 삭제 안내가 표시됩니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text('고객센터'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '문의하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  supportEmail,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '평일 10:00–18:00 (공휴일 제외)\n'
                  '앱 내 채팅·지원 문의는 해당 공고 채팅방을 이용해 주세요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(text: supportEmail),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('이메일 주소를 복사했습니다.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('이메일 복사'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '자주 묻는 질문',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ..._faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CorporateSurfaceCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    faq.$1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          faq.$2,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

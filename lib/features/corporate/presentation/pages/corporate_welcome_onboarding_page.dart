import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/services/corporate_onboarding_service.dart';

/// 기업회원 가입 직후 — 서비스 차별점 3단계 소개
class CorporateWelcomeOnboardingPage extends StatefulWidget {
  const CorporateWelcomeOnboardingPage({super.key});

  @override
  State<CorporateWelcomeOnboardingPage> createState() =>
      _CorporateWelcomeOnboardingPageState();
}

class _CorporateWelcomeOnboardingPageState
    extends State<CorporateWelcomeOnboardingPage> {
  final _pageController = PageController();
  final _onboarding = CorporateOnboardingService();
  int _page = 0;

  static List<_OnboardingSlide> get _slides {
    if (ProductFeatureFlags.isPermanentHireEnabled) {
      return const [
        _OnboardingSlide(
          icon: Icons.work_outline_rounded,
          title: '일용직·상시직,\n한곳에서 매칭',
          body: '단기 출근이 필요한 날은 일용직 공고로,\n'
              '장기 재직자는 상시직으로 관리하세요.\n'
              '하나의 기업 계정으로 모두 운영할 수 있습니다.',
        ),
        _OnboardingSlide(
          icon: Icons.map_outlined,
          title: '지도 기반\n스마트 채용',
          body: '근무지 도로명 주소를 기준으로\n'
              '공고 노출 범위 설정으로 주변 구직자에게 공고를 알립니다.\n'
              '공고 등록은 무료, 넓은 노출은 패키지로 확장하세요.',
        ),
        _OnboardingSlide(
          icon: Icons.verified_user_outlined,
          title: '투명한 수수료\n·컴플라이언스',
          body: '일용직은 출근 확인 시, 상시직은 건강보험 재직 확인 후\n'
              '30일마다 수수료가 정산됩니다.\n'
              '기본 플랜에서도 지원자 연락·채팅을 이용할 수 있습니다.',
        ),
      ];
    }
    return const [
      _OnboardingSlide(
        icon: Icons.work_outline_rounded,
        title: '일용직 현장,\n한곳에서 매칭',
        body: '물류·식품 공장 등 현장 일용직 공고를\n'
            '하나의 기업 계정으로 등록·관리하세요.\n'
            '도급·아웃소싱 인력 투입에도 활용할 수 있습니다.',
      ),
      _OnboardingSlide(
        icon: Icons.map_outlined,
        title: '지도 기반\n스마트 채용',
        body: '근무지 도로명 주소를 기준으로\n'
            '공고 노출 범위 설정으로 주변 구직자에게 공고를 알립니다.\n'
            '공고 등록은 무료, 넓은 노출은 패키지로 확장하세요.',
      ),
      _OnboardingSlide(
        icon: Icons.verified_user_outlined,
        title: '투명한 수수료\n·컴플라이언스',
        body: '일용직은 출근 확인 시 수수료가 정산됩니다.\n'
            '기본 플랜에서도 지원자 연락·채팅을 이용할 수 있습니다.',
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey ?? '';
    await _onboarding.markComplete(companyKey);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  void _next() {
    if (_page >= _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('건너뛰기'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == index
                        ? AppColors.primary
                        : AppColors.searchBarBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _page >= _slides.length - 1 ? '시작하기' : '다음',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
            Text(
              AppStrings.platformTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

import 'package:flutter/material.dart';
import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/legal/widgets/site_legal_footer.dart';

/// Auth 화면 공통 — 짙은 퍼플 배경 + 상단 타이틀
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.bottom,
    this.leading,
  });

  final Widget body;
  final Widget? bottom;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.authBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    if (leading != null) leading!,
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '일자리',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: IljariAdCampaignCopy(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      body,
                      const SizedBox(height: 20),
                      const SiteLegalFooter(variant: SiteLegalFooterVariant.dark),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (bottom != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: bottom!,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

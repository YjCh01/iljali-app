import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';

/// 이용약관·개인정보처리방침 (플레이스홀더 — 법무 검토 전)
class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  static const termsOfService = '''
일자리 서비스 이용약관 (시행일: 2026년 1월 1일)

제1조 (목적)
본 약관은 일자리(이하 "회사")가 제공하는 일용직·현장 채용 중개 플랫폼 서비스(이하 "서비스")의 이용조건 및 절차, 회사와 이용자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (정의)
① "기업회원"이란 사업자등록을 완료하고 공고 등록·지원자 관리 기능을 이용하는 회원을 말합니다.
② "개인회원"이란 구직·지원·채팅 기능을 이용하는 회원을 말합니다.
③ "알림핀"이란 공고 노출·PUSH 발송에 사용되는 유료·보너스 크레딧을 말합니다.

제3조 (약관의 효력 및 변경)
회사는 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 시 앱 내 공지 또는 전자우편으로 안내합니다.

제4조 (서비스의 제공)
① 회사는 지도 기반 공고 노출, 지원·채팅, 근태 확인, 수수료 정산 등의 기능을 제공합니다.
② 공고 등록은 무료이며, 추가 노출·PUSH는 알림핀 정책에 따릅니다.

제5조 (회원의 의무)
회원은 허위 정보 등록, 타인 사칭, 부정 이용, 노쇼 반복 등 서비스 운영을 방해하는 행위를 하여서는 안 됩니다.

제6조 (수수료)
일용직 출근 확인 완료 시 회사가 정한 수수료가 부과될 수 있습니다. 상세 금액은 앱 내 안내를 따릅니다.

제7조 (면책)
회사는 이용자 간 근로계약·임금 지급 등 직접 거래에 관여하지 않으며, 당사자 간 분쟁에 대해 법령이 정한 범위 내에서 책임을 집니다.

제8조 (분쟁 해결)
본 약관은 대한민국 법률에 따르며, 분쟁 발생 시 회사 본점 소재지 관할 법원을 전속 관할로 합니다.

※ 본 문서는 서비스 오픈 전 플레이스홀더이며, 정식 약관은 법무 검토 후 교체됩니다.
''';

  static const privacyPolicy = '''
일자리 개인정보처리방침 (시행일: 2026년 1월 1일)

1. 수집하는 개인정보 항목
- 필수: 이름, 이메일, 휴대전화번호, 회원 유형
- 기업회원: 사업자등록번호, 회사명, 담당자 정보, 사업장 주소
- 개인회원: 생년월일, 성별, 희망 지역·직종, 근무 가능 일정(선택)
- 서비스 이용 과정: 지원·채팅·근태 기록, 결제·알림핀 사용 내역, 기기 정보

2. 개인정보의 수집·이용 목적
- 회원 가입·본인 확인, 공고·지원·채팅 매칭, 근태·수수료 정산
- 알림 발송, 고객 문의 응대, 서비스 개선·부정 이용 방지
- 사업자 검증, 건강보험 재직 확인(해당 시)

3. 보유 및 이용 기간
- 회원 탈퇴 시까지 (관련 법령에 따른 보관 기간 별도 적용)
- 거래·분쟁 관련 기록: 관련 법령에 따른 기간

4. 제3자 제공
원칙적으로 이용자 동의 없이 제3자에게 제공하지 않습니다. 다만 법령에 따른 요청, 결제·인증·지도·알림톡 등 서비스 제공에 필요한 수탁 업체에는 최소한의 정보가 제공될 수 있습니다.

5. 이용자의 권리
이용자는 개인정보 열람·정정·삭제·처리정지를 요청할 수 있으며, 고객센터(support@iljari.co.kr)로 문의할 수 있습니다.

6. 개인정보 보호책임자
- 담당: 일자리 개인정보보호팀
- 이메일: privacy@iljari.co.kr

※ 본 문서는 서비스 오픈 전 플레이스홀더이며, 정식 방침은 법무 검토 후 교체됩니다.
''';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: const AppBackButton(),
          title: const Text('약관 및 정책'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: '이용약관'),
              Tab(text: '개인정보처리방침'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LegalScroll(text: termsOfService),
            _LegalScroll(text: privacyPolicy),
          ],
        ),
      ),
    );
  }
}

class _LegalScroll extends StatelessWidget {
  const _LegalScroll({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Text(
        text.trim(),
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          color: AppColors.textPrimary.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

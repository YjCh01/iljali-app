// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 네이버 로그인 검수용 서비스 소개·운영정책 PDF
///
/// 실행: dart run tool/generate_naver_login_review_pdf.dart
Future<void> main() async {
  final outDir = Directory('store/naver_login_review');
  outDir.createSync(recursive: true);

  final fontPath = 'store/naver_login_review/fonts/NotoSansKR-Regular.otf';
  if (!File(fontPath).existsSync()) {
    stderr.writeln('한글 폰트가 없습니다: $fontPath');
    stderr.writeln('README의 폰트 다운로드 안내를 확인하세요.');
    exit(1);
  }

  final fontData = await File(fontPath).readAsBytes();
  final font = pw.Font.ttf(ByteData.sublistView(fontData));
  final fontBold = font;

  final doc = pw.Document(
    title: '일자리 서비스 소개 및 운영정책',
    author: '아라컴퍼니',
    creator: 'iljari-app',
  );

  pw.Widget h1(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: fontBold, fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget h2(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6, top: 10),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget body(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 3),
        ),
      );

  pw.Widget bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 3),
              ),
            ),
          ],
        ),
      );

  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 108,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(font: font, fontSize: 10, lineSpacing: 3),
              ),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '일자리(iljari) — 네이버 로그인 검수 제출용',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '아라컴퍼니 · iljari.app',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          '서비스 소개 및 운영정책 소명서',
          style: pw.TextStyle(font: fontBold, fontSize: 20),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '네이버 로그인 애플리케이션 검수 재신청 첨부 자료',
          style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        h1('1. 사업자·서비스 기본 정보'),
        infoRow('상호(법인명)', '아라컴퍼니'),
        infoRow('서비스명', '일자리 (iljari)'),
        infoRow('대표자', '최영진'),
        infoRow('사업자등록번호', '540-31-00894'),
        infoRow('소재지', '서울 송파구 오금로11길 55, 현대빌딩 2층 비즈센터'),
        infoRow('서비스 URL', 'https://iljari.app'),
        infoRow('API URL', 'https://api.iljari.app'),
        infoRow('요금 안내', 'https://iljari.app/pricing'),
        infoRow('문의', 'iljariapp@gmail.com · 1644-5701'),
        pw.SizedBox(height: 8),
        h1('2. 서비스 개요'),
        body(
          '일자리는 지도 기반 일용직·현장직 채용 중개 플랫폼입니다. '
          '물류·창고·현장 등에서 단기·일용 인력을 필요로 하는 기업(기업회원)과 '
          '구직자(개인회원)를 연결합니다. 회사는 파견사·인력공급사·아웃소싱 업체가 아니며, '
          '기업과 구직자 간 직접 고용(일용직·현장 채용)을 중개합니다.',
        ),
        h2('2-1. 주요 기능'),
        bullet('구직자: 지도 기반 공고 탐색, 2단계 지원, 기업과 1:1 채팅, 셔틀 예약·근태 확인'),
        bullet('기업회원: 무료 공고 등록, 알림핀·PUSH로 주변 구직자 알림, 지원자 관리, 유료 노출'),
        bullet('위치 기반: 근무지 좌표·반경 기반 PUSH, 네이버 지도 연동'),
        h2('2-2. 제공 콘텐츠(구인구직) 유형'),
        bullet('일용직·단기 현장 채용 공고(근무지, 시급, 근무시간, 모집 인원, 업무 요약)'),
        bullet('기업-구직자 간 지원·매칭·채용 관련 채팅'),
        bullet('근무지·셔틀 정류장 등 위치 정보(지도 노출)'),
        body(
          '본 서비스는 인력공급·파견·도급·헤드헌팅·채용대행 목적의 공고 등록을 '
          '약관상 금지하며, 해당 목적 이용 시 승인·제재 대상입니다.',
        ),
        h1('3. 부적절 구인구직 콘텐츠 방지 — 운영정책'),
        h2('3-1. 기업회원 사전 검증'),
        bullet('기업회원 가입 시 사업자등록번호 필수 제출'),
        bullet('국세청(NTS) API를 통한 사업자 상태·개업일자 확인'),
        bullet('사업자등록증 OCR과 대표자명 교차검증 — 불일치 시 관리자 수동 검토 후 승인'),
        bullet('미인증·검토 대기 기업은 공고 노출·유료 서비스 이용 제한 가능'),
        h2('3-2. 금지 행위(이용약관·별도 약관)'),
        bullet('허위 공고, 허위 경력, 타인 정보 도용'),
        bullet('플랫폼 외 연락처·계좌 유도로 수수료·안전장치 회피'),
        bullet('인력공급·파견·아웃소싱·용역·헤드헌팅 목적의 부정 이용'),
        bullet('노쇼(no-show) 반복, 악성 채팅·욕설·차별·성희롱'),
        bullet('자동화·스크래핑 등 비정상 트래픽'),
        h2('3-3. 위반 시 조치(단계적 제재)'),
        bullet('1단계: 주의 — 위반 사실 통지'),
        bullet('2단계: 경고 — 반복·중대 위반 시'),
        bullet('3단계: 이용제재 — 공고 비노출, 계정 정지, 영구 이용 제한'),
        bullet('직업안정법·파견법 등 관련 법령 위반 시 관계 기관 통지 가능'),
        h1('4. 관리 시스템(운영자 도구)'),
        body('운영자(Admin) 전용 화면을 통해 다음을 모니터링·조치합니다.'),
        bullet('대시보드: 회원·공고·결제·이용 현황 통계'),
        bullet('기업·이용권: 사업자별 이용권·보유금·노출 권한 관리'),
        bullet('회원·제재: 구인자·구직자 제재 부여·해제, 제재 이력 조회'),
        bullet('공고·핀: 지도 핀·공고 상태·노출 관리'),
        bullet('감사 로그: 관리자 조치 이력 기록'),
        bullet('사업자 검증 큐: OCR·NTS 불일치 건 수동 승인/반려'),
        h1('5. 약관·정책 공개'),
        bullet('이용약관, 개인정보처리방침: 앱 내 「더보기 → 약관 및 정책」 및 웹 iljari.app'),
        bullet('아웃소싱·인력공급 이용 제한 약관: 기업회원 가입 시 필수 동의'),
        bullet('커뮤니티·채팅 운영정책: 신고 접수·키워드 필터·표본 검수'),
        bullet('위치기반서비스 이용약관: 지도·GPS 이용 시 고지'),
        h1('6. 네이버 로그인 이용 범위'),
        body(
          '네이버 로그인은 회원 식별·간편 가입·로그인 목적으로만 사용합니다. '
          '네이버 계정 정보는 본인 확인 및 서비스 이용을 위한 최소 범위에서만 처리하며, '
          '개인정보처리방침에 따라 보관·파기합니다.',
        ),
        h2('6-1. OAuth 콜백 URL'),
        bullet('https://api.iljari.app/v1/auth/social/naver/callback'),
        h1('7. 첨부·참고(별도 제출 권장)'),
        body('본 PDF와 함께 아래 화면 캡처를 추가 첨부할 수 있습니다.'),
        bullet('https://iljari.app 로그인 화면'),
        bullet('구직자 지도·공고 상세 화면'),
        bullet('기업 공고 등록·사업자 검증 화면'),
        bullet('관리자(Admin) 대시보드·제재 화면(운영자 전용)'),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#E8F5E9'),
            border: pw.Border.all(color: PdfColor.fromHex('#81C784')),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            '본 문서는 네이버 로그인 검수 재신청을 위한 서비스 소개 및 '
            '부적절 콘텐츠 방지 운영정책 소명 자료입니다. '
            '문의: iljariapp@gmail.com',
            style: pw.TextStyle(font: font, fontSize: 9, lineSpacing: 3),
          ),
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  final outPath = '${outDir.path}/일자리_서비스소개_네이버로그인검수.pdf';
  await File(outPath).writeAsBytes(bytes);
  print('✓ PDF 생성 완료: $outPath');
  print('  크기: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
}

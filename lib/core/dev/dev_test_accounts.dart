import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_credential_holding.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';

/// 로컬 MVP 개발·QA용 고정 테스트 계정.
///
/// **로그인 방법**
/// 1. 앱 시작 화면(회원 유형 선택) 하단 **「개발 테스트 로그인」** 버튼
/// 2. 또는 일반 로그인 화면에서 아래 이메일·비밀번호 입력 (debug 빌드만)
///
/// | 역할 | 이메일 | 비밀번호 | 용도 |
/// |------|--------|----------|------|
/// | 기업 α | corp-alpha@test.iljari.co.kr | Test1234! | 검증완료 · 지원자·채팅·근태 |
/// | 기업 β | corp-beta@test.iljari.co.kr | Test1234! | 검증완료 · 2번째 기업 시나리오 |
/// | 구직 α | seeker-alpha@test.iljari.co.kr | Test1234! | 지원·채팅·근무합의 |
/// | 구직 β | seeker-beta@test.iljari.co.kr | Test1234! | 2번째 구직자 시나리오 |
abstract final class DevTestAccounts {
  static const sharedPassword = 'Test1234!';

  static const corpAlpha = DevTestAccount(
    id: 'corp_alpha',
    label: '테스트기업 알파',
    email: 'corp-alpha@test.iljari.co.kr',
    password: sharedPassword,
    memberType: MemberType.corporate,
    displayName: '테스트기업 알파',
    phone: '010-1000-0001',
    businessRegistrationNumber: '1000000001',
    companyName: '테스트기업 알파',
    department: '채용',
    contactPersonName: '김담당',
    handlerCode: '1001',
  );

  static const corpBeta = DevTestAccount(
    id: 'corp_beta',
    label: '테스트기업 베타',
    email: 'corp-beta@test.iljari.co.kr',
    password: sharedPassword,
    memberType: MemberType.corporate,
    displayName: '테스트기업 베타',
    phone: '010-1000-0002',
    businessRegistrationNumber: '1000000002',
    companyName: '테스트기업 베타',
    department: '인사',
    contactPersonName: '이매니저',
    handlerCode: '2001',
  );

  static const seekerAlpha = DevTestAccount(
    id: 'seeker_alpha',
    label: '테스트구직자 알파',
    email: 'seeker-alpha@test.iljari.co.kr',
    password: sharedPassword,
    memberType: MemberType.individual,
    displayName: '테스트구직자 알파',
    phone: '010-2000-0001',
  );

  static const seekerBeta = DevTestAccount(
    id: 'seeker_beta',
    label: '테스트구직자 베타',
    email: 'seeker-beta@test.iljari.co.kr',
    password: sharedPassword,
    memberType: MemberType.individual,
    displayName: '테스트구직자 베타',
    phone: '010-2000-0002',
  );

  static const all = [
    corpAlpha,
    corpBeta,
    seekerAlpha,
    seekerBeta,
  ];

  static DevTestAccount? matchCredentials({
    required String email,
    required String password,
  }) {
    final normalized = email.trim().toLowerCase();
    for (final account in all) {
      if (account.email == normalized && account.password == password) {
        return account;
      }
    }
    return null;
  }

  static DevTestAccount? byId(String id) {
    for (final account in all) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// debug 채팅·지원 시드 연동용
  static DevTestAccount? corporateByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in [corpAlpha, corpBeta]) {
      if (account.email == normalized) return account;
    }
    return null;
  }

  static DevTestAccount? seekerByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in [seekerAlpha, seekerBeta]) {
      if (account.email == normalized) return account;
    }
    return null;
  }
}

/// 단일 개발 테스트 계정 정의
final class DevTestAccount {
  const DevTestAccount({
    required this.id,
    required this.label,
    required this.email,
    required this.password,
    required this.memberType,
    required this.displayName,
    this.phone,
    this.businessRegistrationNumber,
    this.companyName,
    this.department,
    this.contactPersonName,
    this.handlerCode,
  });

  final String id;
  final String label;
  final String email;
  final String password;
  final MemberType memberType;
  final String displayName;
  final String? phone;
  final String? businessRegistrationNumber;
  final String? companyName;
  final String? department;
  final String? contactPersonName;
  final String? handlerCode;

  bool get isCorporate => memberType == MemberType.corporate;

  CorporateMemberProfile? get verifiedCorporateProfile {
    if (!isCorporate) return null;
    return CorporateMemberProfile(
      companyName: companyName!,
      businessRegistrationNumber: businessRegistrationNumber!,
      department: department!,
      contactPersonName: contactPersonName!,
      handlerCode: handlerCode!,
      verificationStatus: BusinessVerificationStatus.verified,
      requiresAdminReview: false,
      adminReviewApproved: false,
      policyAcceptedAt: DateTime(2026, 1, 1),
      businessHeadOfficeAddress: '경기도 화성시 동탄대로 123',
    );
  }

  AuthUser toAuthUser() {
    return AuthUser(
      name: displayName,
      email: email,
      phone: phone,
      memberType: memberType,
      corporateProfile: verifiedCorporateProfile,
      seekerProfile: verifiedSeekerProfile,
    );
  }

  SeekerMemberProfile? get verifiedSeekerProfile {
    if (isCorporate) return null;
    if (id == 'seeker_beta') {
      return SeekerMemberProfile(
        phoneVerified: true,
        dateOfBirth: DateTime(1998, 7, 22),
        gender: SeekerGender.female,
        nationality: SeekerNationality.domestic,
        preferredRegions: const ['세종', '대전'],
        preferredJobCategories: const ['식품·공장', '청소·환경'],
        experienceSummary: '매장·주방 보조 경력 2년',
        workAvailability: const SeekerWorkAvailability(
          slots: [
            SeekerAvailabilitySlot(weekday: 1, anyTime: true),
            SeekerAvailabilitySlot(weekday: 3, anyTime: true),
            SeekerAvailabilitySlot(weekday: 5, anyTime: true),
          ],
        ),
        credentialHoldings: const [
          SeekerCredentialHolding(
            credentialId: 'construction_safety_basic',
            imagePath: 'qc://credential/construction_safety_basic',
          ),
        ],
        termsAcceptedAt: DateTime(2026, 1, 1),
        onboardingCompletedAt: DateTime(2026, 1, 1),
      );
    }
    return SeekerMemberProfile(
      phoneVerified: true,
      dateOfBirth: DateTime(1995, 3, 15),
      gender: SeekerGender.male,
      nationality: SeekerNationality.domestic,
      preferredRegions: const ['경기', '서울'],
      preferredJobCategories: const ['물류·입출고', '포장·피킹'],
      experienceSummary: '물류센터 피킹·입고 경력 1년',
      workAvailability: const SeekerWorkAvailability(
        slots: [
          SeekerAvailabilitySlot(weekday: 0, anyTime: true),
          SeekerAvailabilitySlot(weekday: 2, anyTime: true),
          SeekerAvailabilitySlot(weekday: 4, anyTime: true),
        ],
      ),
      credentialHoldings: const [
        SeekerCredentialHolding(
          credentialId: 'forklift_operator_cert',
          imagePath: 'qc://credential/forklift_operator_cert',
        ),
      ],
      homeRoadAddress: '서울특별시 송파구 올림픽로 300',
      homeLatitude: 37.5128,
      homeLongitude: 127.0471,
      locationConsentAcceptedAt: DateTime(2026, 1, 1),
      locationConsentVersion: LegalConsentCatalog.locationBasedVersion,
      termsAcceptedAt: DateTime(2026, 1, 1),
      onboardingCompletedAt: DateTime(2026, 1, 1),
    );
  }
}

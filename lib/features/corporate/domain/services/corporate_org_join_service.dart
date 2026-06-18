import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 기업 프로필 저장·가입 시 BRN 조직 자동 가입
class CorporateOrgJoinService {
  const CorporateOrgJoinService();

  Future<void> syncCurrentUser() async {
    final user = AuthSession.instance.currentUser;
    if (user == null || !user.isCorporate) return;
    final profile = user.corporateProfile;
    if (profile == null) return;
    await syncProfile(
      email: user.email,
      name: user.name,
      phone: user.phone,
      profile: profile,
    );
  }

  Future<void> syncProfile({
    required String email,
    required String name,
    required CorporateMemberProfile profile,
    String? phone,
  }) async {
    final repo = await CorporateOrganizationRepository.create();
    await repo.joinMember(
      companyKey: profile.companyKey,
      email: email,
      name: name,
      handlerCode: profile.handlerCode,
      department: profile.department,
      contactPersonName: profile.contactPersonName,
      phone: phone,
    );
  }
}

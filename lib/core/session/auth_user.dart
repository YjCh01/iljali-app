import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 로그인된 사용자 정보 (mock 세션)
class AuthUser {
  const AuthUser({
    required this.name,
    required this.email,
    required this.memberType,
    this.phone,
    this.corporateProfile,
    this.seekerProfile,
  });

  final String name;
  final String email;
  final MemberType memberType;
  final String? phone;
  final CorporateMemberProfile? corporateProfile;
  final SeekerMemberProfile? seekerProfile;

  bool get isCorporate => memberType == MemberType.corporate;
  bool get isIndividual => memberType == MemberType.individual;

  AuthUser copyWith({
    String? name,
    String? email,
    MemberType? memberType,
    String? phone,
    CorporateMemberProfile? corporateProfile,
    SeekerMemberProfile? seekerProfile,
  }) {
    return AuthUser(
      name: name ?? this.name,
      email: email ?? this.email,
      memberType: memberType ?? this.memberType,
      phone: phone ?? this.phone,
      corporateProfile: corporateProfile ?? this.corporateProfile,
      seekerProfile: seekerProfile ?? this.seekerProfile,
    );
  }
}

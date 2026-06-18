/// 기업 조직 내 담당자 역할
enum CorporateOrgRole {
  recruiter,
  paymentAuthority,
}

extension CorporateOrgRoleX on CorporateOrgRole {
  String get label => switch (this) {
        CorporateOrgRole.recruiter => '채용 담당자',
        CorporateOrgRole.paymentAuthority => '결제 권한자',
      };

  String get storageKey => name;
}

CorporateOrgRole parseCorporateOrgRole(String? raw) {
  if (raw == null) return CorporateOrgRole.recruiter;
  try {
    return CorporateOrgRole.values.byName(raw);
  } on ArgumentError {
    return CorporateOrgRole.recruiter;
  }
}

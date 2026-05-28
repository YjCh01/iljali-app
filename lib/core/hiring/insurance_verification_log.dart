enum InsuranceVerificationStatus {
  verified,
  rejected,
}

/// 건강보험 자격득실 확인서 간편인증 이력
class InsuranceVerificationLog {
  const InsuranceVerificationLog({
    required this.id,
    required this.employmentId,
    required this.workplaceName,
    required this.employerCompanyName,
    required this.companyNameMatched,
    required this.employedConfirmed,
    required this.verifiedAt,
    required this.expiresAt,
    required this.status,
    this.method = 'simple_auth',
    this.rejectionReason,
    this.authProvider,
    this.certificateProvider,
    this.cycleNumber = 0,
    this.simpleAuthSessionId,
    this.ciHash,
  });

  final String id;
  final String employmentId;
  final String workplaceName;
  final String employerCompanyName;
  final bool companyNameMatched;
  final bool employedConfirmed;
  final DateTime verifiedAt;
  final DateTime expiresAt;
  final InsuranceVerificationStatus status;
  final String method;
  final String? rejectionReason;
  /// naver | kakao | toss | pass
  final String? authProvider;
  /// codef | hyphen | mock
  final String? certificateProvider;
  final int cycleNumber;
  final String? simpleAuthSessionId;
  /// CI 해시만 저장 (원문 미보관)
  final String? ciHash;

  bool isValidAt(DateTime at) =>
      status == InsuranceVerificationStatus.verified &&
      companyNameMatched &&
      employedConfirmed &&
      !at.isBefore(verifiedAt) &&
      at.isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'employmentId': employmentId,
        'workplaceName': workplaceName,
        'employerCompanyName': employerCompanyName,
        'companyNameMatched': companyNameMatched,
        'employedConfirmed': employedConfirmed,
        'verifiedAt': verifiedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': status.name,
        'method': method,
        'rejectionReason': rejectionReason,
        'authProvider': authProvider,
        'certificateProvider': certificateProvider,
        'cycleNumber': cycleNumber,
        'simpleAuthSessionId': simpleAuthSessionId,
        'ciHash': ciHash,
      };

  factory InsuranceVerificationLog.fromJson(Map<String, dynamic> json) {
    return InsuranceVerificationLog(
      id: json['id'] as String? ?? '',
      employmentId: json['employmentId'] as String? ?? '',
      workplaceName: json['workplaceName'] as String? ?? '',
      employerCompanyName: json['employerCompanyName'] as String? ?? '',
      companyNameMatched: json['companyNameMatched'] as bool? ?? false,
      employedConfirmed: json['employedConfirmed'] as bool? ?? false,
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now(),
      status: InsuranceVerificationStatus.values.byName(
        json['status'] as String? ?? InsuranceVerificationStatus.rejected.name,
      ),
      method: json['method'] as String? ?? 'simple_auth',
      rejectionReason: json['rejectionReason'] as String?,
      authProvider: json['authProvider'] as String?,
      certificateProvider: json['certificateProvider'] as String?,
      cycleNumber: json['cycleNumber'] as int? ?? 0,
      simpleAuthSessionId: json['simpleAuthSessionId'] as String?,
      ciHash: json['ciHash'] as String?,
    );
  }
}

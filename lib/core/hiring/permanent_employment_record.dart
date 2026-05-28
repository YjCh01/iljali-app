import 'package:map/core/hiring/permanent_commission_policy.dart';

/// 상시직 채용 건 — 입사일·월급 기준 30일 주기 수수료
class PermanentEmploymentRecord {
  const PermanentEmploymentRecord({
    required this.id,
    required this.applicationId,
    required this.companyKey,
    required this.companyName,
    required this.seekerEmail,
    required this.seekerName,
    required this.monthlySalaryKrw,
    required this.hireDate,
    this.active = true,
    required this.createdAt,
  });

  final String id;
  final String applicationId;
  final String companyKey;
  final String companyName;
  final String seekerEmail;
  final String seekerName;
  final int monthlySalaryKrw;
  final DateTime hireDate;
  final bool active;
  final DateTime createdAt;

  DateTime get initialVerificationDeadline => hireDate.add(
        const Duration(
          days: PermanentCommissionPolicy.initialVerificationDeadlineDays,
        ),
      );

  DateTime billingDueAt(int completedCycles) => hireDate.add(
        Duration(
          days: PermanentCommissionPolicy.billingCycleDays * (completedCycles + 1),
        ),
      );

  PermanentEmploymentRecord copyWith({bool? active}) {
    return PermanentEmploymentRecord(
      id: id,
      applicationId: applicationId,
      companyKey: companyKey,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName,
      monthlySalaryKrw: monthlySalaryKrw,
      hireDate: hireDate,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'applicationId': applicationId,
        'companyKey': companyKey,
        'companyName': companyName,
        'seekerEmail': seekerEmail,
        'seekerName': seekerName,
        'monthlySalaryKrw': monthlySalaryKrw,
        'hireDate': hireDate.toIso8601String(),
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PermanentEmploymentRecord.fromJson(Map<String, dynamic> json) {
    return PermanentEmploymentRecord(
      id: json['id'] as String? ?? '',
      applicationId: json['applicationId'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      seekerName: json['seekerName'] as String? ?? '',
      monthlySalaryKrw: json['monthlySalaryKrw'] as int? ?? 0,
      hireDate: DateTime.tryParse(json['hireDate'] as String? ?? '') ??
          DateTime.now(),
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

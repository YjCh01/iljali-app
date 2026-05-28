enum MonthlyCommissionStatus {
  charged,
  skipped,
  pending,
}

/// 상시직 30일 주기 월 수수료 청구 내역
class MonthlyCommission {
  const MonthlyCommission({
    required this.id,
    required this.employmentId,
    required this.periodStart,
    required this.periodEnd,
    required this.monthlySalaryKrw,
    required this.commissionRate,
    required this.amountKrw,
    required this.status,
    this.chargedAt,
    this.skipReason,
    required this.createdAt,
  });

  final String id;
  final String employmentId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int monthlySalaryKrw;
  final double commissionRate;
  final int amountKrw;
  final MonthlyCommissionStatus status;
  final DateTime? chargedAt;
  final String? skipReason;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'employmentId': employmentId,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'monthlySalaryKrw': monthlySalaryKrw,
        'commissionRate': commissionRate,
        'amountKrw': amountKrw,
        'status': status.name,
        'chargedAt': chargedAt?.toIso8601String(),
        'skipReason': skipReason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MonthlyCommission.fromJson(Map<String, dynamic> json) {
    return MonthlyCommission(
      id: json['id'] as String? ?? '',
      employmentId: json['employmentId'] as String? ?? '',
      periodStart: DateTime.tryParse(json['periodStart'] as String? ?? '') ??
          DateTime.now(),
      periodEnd: DateTime.tryParse(json['periodEnd'] as String? ?? '') ??
          DateTime.now(),
      monthlySalaryKrw: json['monthlySalaryKrw'] as int? ?? 0,
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ?? 0.055,
      amountKrw: json['amountKrw'] as int? ?? 0,
      status: MonthlyCommissionStatus.values.byName(
        json['status'] as String? ?? MonthlyCommissionStatus.pending.name,
      ),
      chargedAt: DateTime.tryParse(json['chargedAt'] as String? ?? ''),
      skipReason: json['skipReason'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

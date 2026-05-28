/// 급여 단위
enum SalaryPayType {
  hourly,
  daily,
  weekly,
  monthly,
}

SalaryPayType parseSalaryPayType(String raw) {
  final trimmed = raw.trim();
  for (final type in SalaryPayType.values) {
    if (trimmed.startsWith(type.label)) return type;
  }
  return SalaryPayType.hourly;
}

String salaryPayDigits(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

extension SalaryPayTypeX on SalaryPayType {
  String get label => switch (this) {
        SalaryPayType.hourly => '시급',
        SalaryPayType.daily => '일급',
        SalaryPayType.weekly => '주급',
        SalaryPayType.monthly => '월급',
      };

  String formatAmount(String digits) {
    if (digits.isEmpty) return label;
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$label $formatted원';
  }
}

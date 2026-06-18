/// 회사 단위 저장 결제수단 (PG 빌링키 토큰)
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.companyKey,
    required this.label,
    required this.cardBrand,
    required this.last4,
    required this.billingKey,
    required this.registeredAt,
    required this.registeredByEmail,
    this.isDefault = false,
  });

  final String id;
  final String companyKey;
  final String label;
  final String cardBrand;
  final String last4;
  final String billingKey;
  final DateTime registeredAt;
  final String registeredByEmail;
  final bool isDefault;

  String get displayLabel => '$cardBrand ****$last4';

  SavedPaymentMethod copyWith({
    bool? isDefault,
  }) {
    return SavedPaymentMethod(
      id: id,
      companyKey: companyKey,
      label: label,
      cardBrand: cardBrand,
      last4: last4,
      billingKey: billingKey,
      registeredAt: registeredAt,
      registeredByEmail: registeredByEmail,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'label': label,
        'cardBrand': cardBrand,
        'last4': last4,
        'billingKey': billingKey,
        'registeredAt': registeredAt.toIso8601String(),
        'registeredByEmail': registeredByEmail,
        'isDefault': isDefault,
      };

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      id: json['id'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      cardBrand: json['cardBrand'] as String? ?? '카드',
      last4: json['last4'] as String? ?? '0000',
      billingKey: json['billingKey'] as String? ?? '',
      registeredAt: DateTime.tryParse(json['registeredAt'] as String? ?? '') ??
          DateTime.now(),
      registeredByEmail: json['registeredByEmail'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

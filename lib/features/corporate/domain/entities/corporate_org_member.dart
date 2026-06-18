import 'package:map/features/corporate/domain/entities/corporate_org_role.dart';

/// 동일 사업자등록번호(BRN) 조직 구성원
class CorporateOrgMember {
  const CorporateOrgMember({
    required this.email,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.handlerCode,
    this.department,
    this.contactPersonName,
    this.phone,
  });

  final String email;
  final String name;
  final CorporateOrgRole role;
  final DateTime joinedAt;
  final String? handlerCode;
  final String? department;
  final String? contactPersonName;
  final String? phone;

  bool get isPaymentAuthority => role == CorporateOrgRole.paymentAuthority;

  String get displayLabel {
    final dept = department?.trim();
    final contact = contactPersonName?.trim();
    if (dept != null && dept.isNotEmpty && contact != null && contact.isNotEmpty) {
      return '$dept · $contact';
    }
    return name;
  }

  CorporateOrgMember copyWith({
    String? name,
    CorporateOrgRole? role,
    String? handlerCode,
    String? department,
    String? contactPersonName,
    String? phone,
  }) {
    return CorporateOrgMember(
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      joinedAt: joinedAt,
      handlerCode: handlerCode ?? this.handlerCode,
      department: department ?? this.department,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'role': role.storageKey,
        'joinedAt': joinedAt.toIso8601String(),
        if (handlerCode != null) 'handlerCode': handlerCode,
        if (department != null) 'department': department,
        if (contactPersonName != null) 'contactPersonName': contactPersonName,
        if (phone != null) 'phone': phone,
      };

  factory CorporateOrgMember.fromJson(Map<String, dynamic> json) {
    return CorporateOrgMember(
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: parseCorporateOrgRole(json['role'] as String?),
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
          DateTime.now(),
      handlerCode: json['handlerCode'] as String?,
      department: json['department'] as String?,
      contactPersonName: json['contactPersonName'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

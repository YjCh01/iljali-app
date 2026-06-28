import 'package:flutter/services.dart';
import 'package:map/features/auth/domain/validators/validation_result.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';

/// 주민등록번호 앞 7자리 (YYMMDD + 성별·세기 구분자리)
abstract final class ResidentIdFront {
  static final RegExp _digitsOnly = RegExp(r'[^0-9]');

  static String digitsOnly(String value) =>
      value.replaceAll(_digitsOnly, '');

  static String formatDisplay(String value) {
    final digits = digitsOnly(value);
    if (digits.length <= 6) return digits;
    return '${digits.substring(0, 6)}-${digits.substring(6)}';
  }

  static ValidationResult validate(String? value) {
    final digits = digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return const ValidationResult.invalid('주민번호 앞 7자리를 입력해 주세요.');
    }
    if (digits.length != 7) {
      return const ValidationResult.invalid(
        '생년월일 6자리와 뒤 1자리를 모두 입력해 주세요.',
      );
    }

    final parsed = tryParse(digits);
    if (parsed == null) {
      return const ValidationResult.invalid(
        '형식이 올바르지 않습니다. (예: 900101-1)',
      );
    }
    return const ValidationResult.valid();
  }

  static ResidentIdFrontData? tryParse(String digits) {
    final normalized = digitsOnly(digits);
    if (normalized.length != 7) return null;

    final yy = int.tryParse(normalized.substring(0, 2));
    final mm = int.tryParse(normalized.substring(2, 4));
    final dd = int.tryParse(normalized.substring(4, 6));
    final genderDigit = int.tryParse(normalized.substring(6, 7));
    if (yy == null || mm == null || dd == null || genderDigit == null) {
      return null;
    }
    if (genderDigit < 0 || genderDigit > 9) return null;

    final century = switch (genderDigit) {
      1 || 2 || 5 || 6 => 1900,
      3 || 4 || 7 || 8 => 2000,
      9 || 0 => 1800,
      _ => null,
    };
    if (century == null) return null;

    final year = century + yy;
    final birthDate = DateTime(year, mm, dd);
    if (birthDate.year != year ||
        birthDate.month != mm ||
        birthDate.day != dd) {
      return null;
    }

    final gender = switch (genderDigit) {
      1 || 3 || 5 || 7 || 9 => SeekerGender.male,
      2 || 4 || 6 || 8 || 0 => SeekerGender.female,
      _ => null,
    };
    if (gender == null) return null;

    final nationality = switch (genderDigit) {
      5 || 6 || 7 || 8 => SeekerNationality.foreign,
      _ => SeekerNationality.domestic,
    };

    return ResidentIdFrontData(
      digits: normalized,
      birthDate: birthDate,
      gender: gender,
      nationality: nationality,
      genderDigit: genderDigit,
    );
  }
}

class ResidentIdFrontData {
  const ResidentIdFrontData({
    required this.digits,
    required this.birthDate,
    required this.gender,
    required this.nationality,
    required this.genderDigit,
  });

  final String digits;
  final DateTime birthDate;
  final SeekerGender gender;
  final SeekerNationality nationality;
  final int genderDigit;

  String get display => ResidentIdFront.formatDisplay(digits);
}

/// `900101-1` 형식으로 자동 하이픈
class ResidentIdFrontFormatter extends TextInputFormatter {
  const ResidentIdFrontFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = ResidentIdFront.digitsOnly(newValue.text);
    final limited =
        digits.length > 7 ? digits.substring(0, 7) : digits;
    final formatted = ResidentIdFront.formatDisplay(limited);

    var selectionIndex = formatted.length;
    for (var i = 0; i < newValue.selection.end; i++) {
      if (i < limited.length) {
        selectionIndex = i < 6 ? i + 1 : i + 2;
      }
    }
    selectionIndex = selectionIndex.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

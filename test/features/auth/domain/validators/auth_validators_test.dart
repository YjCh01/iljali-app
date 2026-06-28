import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/auth/domain/validators/email_validator.dart';
import 'package:map/features/auth/domain/validators/name_validator.dart';
import 'package:map/features/auth/domain/validators/password_confirm_validator.dart';
import 'package:map/features/auth/domain/validators/password_validator.dart';
import 'package:map/features/auth/domain/validators/phone_validator.dart';

void main() {
  group('EmailValidator', () {
    test('accepts valid email', () {
      expect(EmailValidator.validate('user@example.com').isValid, isTrue);
    });

    test('rejects empty email', () {
      expect(EmailValidator.validate('').isValid, isFalse);
    });

    test('rejects invalid format', () {
      expect(EmailValidator.validate('not-an-email').isValid, isFalse);
    });
  });

  group('PhoneValidator', () {
    test('accepts 11 digit mobile number', () {
      expect(PhoneValidator.validate('01012345678').isValid, isTrue);
    });

    test('rejects hyphenated number', () {
      expect(PhoneValidator.validate('010-1234-5678').isValid, isFalse);
    });

    test('rejects short number', () {
      expect(PhoneValidator.validate('0101234').isValid, isFalse);
    });
  });

  group('PasswordValidator', () {
    test('validateRequired only checks empty', () {
      expect(PasswordValidator.validateRequired('abc').isValid, isTrue);
      expect(PasswordValidator.validateRequired('').isValid, isFalse);
    });

    test('validate enforces complexity', () {
      expect(PasswordValidator.validate('short1').isValid, isFalse);
      expect(PasswordValidator.validate('password').isValid, isFalse);
      expect(PasswordValidator.validate('password1').isValid, isTrue);
      expect(PasswordValidator.validate('Passw0rd').isValid, isTrue);
    });
  });

  group('PasswordConfirmValidator', () {
    test('accepts matching passwords', () {
      final result = PasswordConfirmValidator.validate(
        password: 'password1',
        confirm: 'password1',
      );
      expect(result.isValid, isTrue);
    });

    test('rejects mismatched passwords', () {
      final result = PasswordConfirmValidator.validate(
        password: 'password1',
        confirm: 'password2',
      );
      expect(result.isValid, isFalse);
    });
  });

  group('NameValidator', () {
    test('accepts name with 2+ characters', () {
      expect(NameValidator.validate('홍길동').isValid, isTrue);
    });

    test('rejects single character name', () {
      expect(NameValidator.validate('김').isValid, isFalse);
    });
  });
}

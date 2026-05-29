import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/domain/business_registration_number.dart';

void main() {
  group('BusinessRegistrationNumber', () {
    test('accepts valid checksum BRN 1234567891', () {
      expect(BusinessRegistrationNumber.isValidChecksum('1234567891'), isTrue);
      expect(BusinessRegistrationNumber.tryParse('1234567891')?.digits, '1234567891');
    });

    test('rejects invalid checksum', () {
      expect(BusinessRegistrationNumber.isValidChecksum('1234567890'), isFalse);
      expect(BusinessRegistrationNumber.tryParse('1234567890'), isNull);
    });

    test('strips non-digit characters before validation', () {
      final parsed = BusinessRegistrationNumber.tryParse('123-45-67891');
      expect(parsed?.digits, '1234567891');
    });

    test('formatErrorMessage covers empty, length, checksum', () {
      expect(BusinessRegistrationNumber.formatErrorMessage(''), isNotNull);
      expect(BusinessRegistrationNumber.formatErrorMessage('123'), isNotNull);
      expect(
        BusinessRegistrationNumber.formatErrorMessage('1234567890'),
        contains('유효하지 않은'),
      );
      expect(BusinessRegistrationNumber.formatErrorMessage('1234567891'), isNull);
    });
  });
}

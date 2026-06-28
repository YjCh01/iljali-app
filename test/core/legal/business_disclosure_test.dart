import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/legal/business_disclosure.dart';

void main() {
  test('ftc verification url uses registration number without dashes', () {
    expect(
      BusinessDisclosure.ftcVerificationUrl,
      contains('searchKrwd=5403100894'),
    );
  });

  test('footer includes business and contact lines', () {
    expect(BusinessDisclosure.footerLines.join('\n'), contains('언리얼리'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('537-58-01045'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('iljariapp@gmail.com'));
  });
}

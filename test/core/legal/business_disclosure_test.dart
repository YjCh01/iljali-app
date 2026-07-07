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
    expect(BusinessDisclosure.footerLines.join('\n'), contains('아라컴퍼니'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('540-31-00894'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('송파구 오금로11길 55'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('iljariapp@gmail.com'));
    expect(BusinessDisclosure.footerLines.join('\n'), contains('1644-5701'));
  });
}

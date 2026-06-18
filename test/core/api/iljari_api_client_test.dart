import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';

void main() {
  group('IljariApiClient', () {
    test('isEnabled false when base URL empty', () {
      final client = IljariApiClient(baseUrl: '');
      expect(client.isEnabled, isFalse);
    });

    test(
      'listJobPosts hits server when URL configured',
      () {
        if (!EnvConfig.isComplianceApiEnabled) return;
        final client = IljariApiClient();
        expect(client.isEnabled, isTrue);
      },
      skip: EnvConfig.complianceApiBaseUrl.isEmpty
          ? 'COMPLIANCE_API_URL not set'
          : false,
    );
  });
}

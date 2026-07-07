import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/dev/qc_visual_scenario_seeder.dart';

void main() {
  test('QcVisualScenario constants stay isolated to QC fixtures', () {
    expect(QcVisualScenario.postId, startsWith('qc_'));
    expect(QcVisualScenario.seekerEmail, contains('@qc.iljari.co.kr'));
    expect(EnvConfig.qcMode, isFalse);
  });
}

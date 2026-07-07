import 'package:flutter/foundation.dart';
import 'package:map/core/config/env_config.dart';

/// 내부 QA·데모 전용 UI — 실서버(release) 빌드에서는 항상 false
abstract final class DevExperienceFlags {
  static bool get enabled => kDebugMode && EnvConfig.qcMode;
}

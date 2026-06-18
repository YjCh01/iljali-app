import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// PUSH 거점 페이지 라우트 인자
class PushBasePointArgs {
  const PushBasePointArgs({
    this.initialSettings,
    this.workplace,
  });

  final JobPostNotificationSettings? initialSettings;
  final WorkplaceAddress? workplace;
}

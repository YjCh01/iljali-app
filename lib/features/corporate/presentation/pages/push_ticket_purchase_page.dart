import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/presentation/widgets/push_ticket_purchase_sheet.dart';

class PushTicketPurchaseArgs {
  const PushTicketPurchaseArgs({
    this.notificationSettings,
    this.shuttleRouteId,
  });

  final JobPostNotificationSettings? notificationSettings;
  final String? shuttleRouteId;
}

/// PUSH 이용권 결제 — 하위 호환용 라우트 래퍼 (실제 UI는 바텀시트)
class PushTicketPurchasePage extends StatefulWidget {
  const PushTicketPurchasePage({super.key, this.args});

  final PushTicketPurchaseArgs? args;

  @override
  State<PushTicketPurchasePage> createState() => _PushTicketPurchasePageState();
}

class _PushTicketPurchasePageState extends State<PushTicketPurchasePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    final purchased = await showPushTicketPurchaseSheet(context);
    if (!mounted) return;
    Navigator.of(context).pop(purchased == true);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/presentation/partnership_upsell_dialog.dart';
import 'package:map/core/compliance/services/abuse_detection_service.dart';
import 'package:map/core/compliance/services/contact_entitlement_service.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/register_permanent_hire_sheet.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';

/// 지원자 ↔ 기업 채팅 (연락 제한·필터 적용)
class ApplicationChatPage extends StatefulWidget {
  const ApplicationChatPage({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  @override
  State<ApplicationChatPage> createState() => _ApplicationChatPageState();
}

class _ApplicationChatPageState extends State<ApplicationChatPage> {
  HiringApplication? _application;
  final _messages = <_ChatMessage>[];
  final _controller = TextEditingController();
  bool _accessDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    final entitlement = ContactEntitlementService();
    final access = await entitlement.recordContactAttempt(
      profile,
      applicationId: widget.applicationId,
      action: 'open_chat_page',
    );
    if (!mounted) return;
    if (!access.allowed) {
      setState(() => _accessDenied = true);
      await ensureContactAccess(context, access);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(widget.applicationId);
    if (!mounted || app == null) return;
    await repo.startChat(widget.applicationId);
    setState(() {
      _application = app;
      _messages.addAll([
        _ChatMessage(
          fromCorporate: true,
          text:
              '안녕하세요, ${app.companyName} 채용 담당입니다.\n「${app.postTitle}」 지원 감사합니다.',
        ),
        _ChatMessage(
          fromCorporate: false,
          text: '안녕하세요, ${app.seekerName}입니다. 출근 일정 문의드립니다.',
        ),
      ]);
    });

    if (app.status == HiringApplicationStatus.checkedIn &&
        app.needsCommissionPayment &&
        mounted) {
      await showCommissionPaymentDialog(context, app);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final violation = ChatContactFilter.validateOutbound(text);
    if (violation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(violation), behavior: SnackBarBehavior.floating),
      );
      ComplianceRepository.create().then((repo) {
        repo.addAbuseFlag({
          'type': 'off_platform_contact',
          'message': violation,
          'applicationId': widget.applicationId,
          'snippet': text.length > 20 ? text.substring(0, 20) : text,
        });
      });
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(fromCorporate: true, text: text));
      _controller.clear();
    });
  }

  Future<void> _instantAccept() async {
    final repo = await LocalHiringRepository.create();
    final updated = await repo.instantAccept(
      applicationId: widget.applicationId,
      workDate: _application?.workDate,
    );
    if (!mounted) return;
    setState(() => _application = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${updated.seekerName}님을 출근 예정자로 확정했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _registerPermanentHire() async {
    final app = _application;
    if (app == null) return;

    final record = await showRegisterPermanentHireSheet(context, app);
    if (!mounted || record == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${record.seekerName}님 상시직 등록 완료. 7일 이내 건강보험 인증이 필요합니다.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final app = _application;
    if (app == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheduled = app.status == HiringApplicationStatus.scheduled ||
        app.status == HiringApplicationStatus.checkedIn ||
        app.status == HiringApplicationStatus.commissionPaid;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final showContactNotice = profile != null && profile.hasActivePaidSubscription;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(app.seekerName),
        actions: [
          if (!scheduled && !app.isPermanentEmployment)
            TextButton(
              onPressed: _instantAccept,
              child: const Text('즉시 확정'),
            ),
          if (app.isPermanentEmployment && ProductFeatureFlags.isPermanentHireEnabled)
            TextButton(
              onPressed: _registerPermanentHire,
              child: const Text('상시직 합격'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「${app.postTitle}」 · ${app.workSchedule}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (showContactNotice)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '연락처: ${app.seekerPhoneMasked} · 플랫폼 내 채팅 (오프플랫폼 유도 차단)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.fromCorporate
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: msg.fromCorporate
                          ? AppColors.primaryLight.withValues(alpha: 0.35)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.searchBarBorder),
                    ),
                    child: Text(msg.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '메시지 입력 (연락처·외부링크 금지)',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: AppColors.searchBarBorder),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.fromCorporate, required this.text});
  final bool fromCorporate;
  final String text;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/compliance/presentation/partnership_upsell_dialog.dart';
import 'package:map/core/compliance/services/abuse_detection_service.dart';
import 'package:map/core/compliance/services/contact_entitlement_service.dart';
import 'package:map/core/dev/dev_chat_test_support.dart';
import 'package:map/core/hiring/chat_room_leave_service.dart';
import 'package:map/core/hiring/application_chat_realtime_client.dart';
import 'package:map/core/hiring/application_chat_message.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/chat_message_kind.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/corporate_job_post_scope.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';
import 'package:map/features/corporate/presentation/widgets/chat/chat_reply_macro_picker_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_preview_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/register_permanent_hire_sheet.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_pin_factory.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_attachment_picker_sheet.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_room_leave_menu.dart';
import 'package:map/features/hiring/presentation/widgets/chat/chat_message_bubble.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_document_repository.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_document_storage.dart';

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
  static const _postsSource = CorporateJobPostLocalDataSourceImpl();

  HiringApplication? _application;
  CorporateJobPost? _jobPost;
  final _messages = <ApplicationChatMessage>[];
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  bool _accessDenied = false;
  ApplicationChatRealtimeClient? _realtime;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  Timer? _fallbackPollTimer;

  bool get _isEmployer =>
      AuthSession.instance.currentUser?.memberType == MemberType.corporate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    unawaited(_realtimeSub?.cancel());
    unawaited(_realtime?.dispose());
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = AuthSession.instance.currentUser;
    if (user == null) return;

    final requester =
        _isEmployer ? MemberType.corporate : MemberType.individual;
    final peer = _isEmployer ? MemberType.individual : MemberType.corporate;
    final policy = ChatAccessPolicy.evaluatePair(
      requester: requester,
      peer: peer,
    );
    if (!policy.allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '채팅 접근이 제한되었습니다.')),
      );
      Navigator.of(context).pop();
      return;
    }

    if (_isEmployer) {
      final profile = user.corporateProfile;
      if (profile == null) return;
      final devReady = kDebugMode &&
          await DevChatTestSupport.ensureCorporateChatReady();
      if (!devReady) {
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
      }
    }

    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(widget.applicationId);
    if (!mounted || app == null) return;

    if (!_isEmployer && app.seekerEmail != user.email) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인 지원 건만 채팅할 수 있습니다.')),
      );
      Navigator.of(context).pop();
      return;
    }

    await repo.startChat(widget.applicationId);

    CorporateJobPost? jobPost;
    if (_isEmployer) {
      jobPost = await _postsSource.findById(app.postId);
      final companyKey = user.corporateProfile?.companyKey;
      if (jobPost != null &&
          companyKey != null &&
          !CorporateJobPostScope.belongsToCompany(jobPost, companyKey)) {
        jobPost = null;
      }
    }

    final chatRepo = await ApplicationChatMessageRepository.create();
    final stored = await chatRepo.loadSynced(
      applicationId: widget.applicationId,
      companyName: app.companyName,
      postTitle: app.postTitle,
      seekerName: app.seekerName,
    );

    setState(() {
      _application = app;
      _jobPost = jobPost;
      _messages
        ..clear()
        ..addAll(stored);
    });

    await _startRealtime(app);

    if (_isEmployer &&
        ProductFeatureFlags.isHiringCommissionEnabled &&
        app.status == HiringApplicationStatus.checkedIn &&
        app.needsCommissionPayment &&
        mounted) {
      await showCommissionPaymentDialog(context, app);
    }
  }

  Future<void> _startRealtime(HiringApplication app) async {
    await _realtimeSub?.cancel();
    await _realtime?.dispose();
    _fallbackPollTimer?.cancel();

    final role = _isEmployer ? 'employer' : 'seeker';
    final client = ApplicationChatRealtimeClient(
      applicationId: widget.applicationId,
      senderRole: role,
      onConnectionStateChanged: _onRealtimeConnectionChanged,
    );
    _realtime = client;

    final chatRepo = await ApplicationChatMessageRepository.create();
    _realtimeSub = client.incomingMessages.listen((row) async {
      final parsed = await chatRepo.applyIncomingRow(widget.applicationId, row);
      if (parsed == null || !mounted) return;
      setState(() => _messages.add(parsed));
    });

    await client.connect();
  }

  void _onRealtimeConnectionChanged(bool connected) {
    _fallbackPollTimer?.cancel();
    if (connected || !mounted) return;
    _fallbackPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshMessages()),
    );
  }

  Future<void> _refreshMessages() async {
    final app = _application;
    if (app == null || !mounted) return;

    final chatRepo = await ApplicationChatMessageRepository.create();
    final stored = await chatRepo.loadSynced(
      applicationId: widget.applicationId,
      companyName: app.companyName,
      postTitle: app.postTitle,
      seekerName: app.seekerName,
    );
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(stored);
    });
  }

  void _insertMacro(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  Future<void> _openMacroPicker() async {
    final app = _application;
    if (app == null) return;
    FocusScope.of(context).unfocus();
    final result = await showChatReplyMacroPickerSheet(
      context,
      application: app,
      jobPost: _jobPost,
    );
    if (!mounted) return;
    if (result == null) return;
    if (result.sendImmediately) {
      _sendMacro(result.text);
    } else {
      _insertMacro(result.text);
      _inputFocus.requestFocus();
    }
  }

  void _sendMacro(String text) {
    _controller.text = text;
    _send();
  }

  Future<void> _confirmWorkSchedule() async {
    final repo = await LocalHiringRepository.create();
    try {
      final updated = await repo.confirmWorkScheduleAgreement(
        applicationId: widget.applicationId,
        asEmployer: _isEmployer,
      );
      if (!mounted) return;
      setState(() => _application = updated);
      final done = updated.isWorkAgreementComplete;
      final waitingPeer = _isEmployer
          ? updated.seekerWorkAgreedAt == null
          : updated.employerWorkAgreedAt == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            done
                ? '근무예정 합의가 완료되었습니다. 근태 탭에서 확인하세요.'
                : waitingPeer
                    ? '확인했습니다. 상대방 확인을 기다리는 중입니다.'
                    : '근무예정 합의를 처리했습니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근무예정 합의를 처리할 수 없습니다.')),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _sendMessage(
      ApplicationChatMessage(
        fromEmployer: _isEmployer,
        text: text,
        sentAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    _controller.clear();
  }

  Future<void> _sendMessage(ApplicationChatMessage message) async {
    if (message.kind == ChatMessageKind.text) {
      final violation = ChatContactFilter.validateOutbound(message.text);
      if (violation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(violation),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ComplianceRepository.create().then((repo) {
          repo.addAbuseFlag({
            'type': 'off_platform_contact',
            'message': violation,
            'applicationId': widget.applicationId,
            'snippet': message.text.length > 20
                ? message.text.substring(0, 20)
                : message.text,
          });
        });
        return;
      }
    }

    final chatRepo = await ApplicationChatMessageRepository.create();
    final stored = await chatRepo.append(widget.applicationId, message);
    if (!mounted) return;
    setState(() {
      if (stored.id != null &&
          _messages.any((item) => item.id == stored.id)) {
        return;
      }
      _messages.add(stored);
    });

    if (message.kind == ChatMessageKind.text &&
        ChatContactFilter.containsPhoneNumber(message.text)) {
      final profile = AuthSession.instance.currentUser?.corporateProfile;
      ComplianceRepository.create().then((repo) {
        repo.logContactEvent({
          'type': 'phone_shared_in_chat',
          'applicationId': widget.applicationId,
          'fromEmployer': message.fromEmployer,
          if (profile != null) 'companyKey': profile.companyKey,
        });
      });
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showAdaptiveSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPhoto() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    final storedPath =
        await persistSeekerDocumentImage(file, 'chat_photo') ?? file.path;

    await _sendMessage(
      ApplicationChatMessage(
        fromEmployer: _isEmployer,
        text: '사진을 보냈습니다.',
        sentAt: DateTime.now(),
        kind: ChatMessageKind.photo,
        attachmentPath: storedPath,
      ),
    );
  }

  Future<void> _sendResume() async {
    final app = _application;
    if (app == null) return;

    if (_isEmployer) {
      await openCorporateApplicantResume(
        context,
        applicationId: widget.applicationId,
      );
      return;
    }

    await _sendMessage(
      ApplicationChatMessage(
        fromEmployer: false,
        text: '${app.seekerName}님의 이력서입니다. 탭하여 확인하세요.',
        sentAt: DateTime.now(),
        kind: ChatMessageKind.resume,
      ),
    );
  }

  Future<void> _sendRegisteredDocument({
    required bool isIdCard,
  }) async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;

    final repo = await SeekerDocumentRepository.create();
    final docs = await repo.load(email);
    final path = isIdCard ? docs.idCardImagePath : docs.bankAccountImagePath;
    final label = isIdCard ? '신분증' : '통장사본';

    if (!docs.isDocumentConsentCurrent) {
      if (!mounted) return;
      final goConsent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('서류 수집·이용 동의 필요'),
          content: Text(
            '$label을 보내려면 신분증·통장사본 수집·이용 및 '
            '구인자 제공에 대한 동의가 필요합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('동의하러 가기'),
            ),
          ],
        ),
      );
      if (goConsent == true && mounted) {
        await Navigator.of(context).pushNamed(AppRoutes.seekerMyDocuments);
      }
      return;
    }

    if (path == null || path.trim().isEmpty) {
      if (!mounted) return;
      final goRegister = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$label 등록 필요'),
          content: Text(
            '내정보에서 $label을 먼저 등록해야 채팅으로 보낼 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('등록하러 가기'),
            ),
          ],
        ),
      );
      if (goRegister == true && mounted) {
        await Navigator.of(context).pushNamed(AppRoutes.seekerMyDocuments);
      }
      return;
    }

    await _sendMessage(
      ApplicationChatMessage(
        fromEmployer: false,
        text: '$label을 보냈습니다.',
        sentAt: DateTime.now(),
        kind: isIdCard ? ChatMessageKind.idCard : ChatMessageKind.bankAccount,
        attachmentPath: path,
      ),
    );
  }

  Future<void> _openAttachmentPicker() async {
    FocusScope.of(context).unfocus();

    SeekerDocuments? docs;
    if (!_isEmployer) {
      final email = AuthSession.instance.currentUser?.email;
      if (email != null) {
        final repo = await SeekerDocumentRepository.create();
        docs = await repo.load(email);
      }
    }

    final options = _isEmployer
        ? [
            const ChatAttachmentOption(
              id: 'photo',
              icon: Icons.photo_outlined,
              label: '사진보내기',
              subtitle: '현장 사진·안내 이미지 전송',
            ),
            const ChatAttachmentOption(
              id: 'resume',
              icon: Icons.description_outlined,
              label: '이력서 보기',
              subtitle: '지원자 탭과 동일한 이력서 화면',
            ),
          ]
        : [
            const ChatAttachmentOption(
              id: 'photo',
              icon: Icons.photo_outlined,
              label: '사진보내기',
              subtitle: '현장 사진·서류 촬영본 전송',
            ),
            const ChatAttachmentOption(
              id: 'resume',
              icon: Icons.description_outlined,
              label: '이력서보내기',
              subtitle: '구인자가 탭하면 이력서를 볼 수 있습니다',
            ),
            ChatAttachmentOption(
              id: 'bank',
              icon: Icons.account_balance_outlined,
              label: '통장사본 전송하기',
              subtitle: docs?.hasBankAccount == true
                  ? '등록된 통장사본 보내기'
                  : '내정보에서 먼저 등록 필요',
              enabled: true,
            ),
            ChatAttachmentOption(
              id: 'id',
              icon: Icons.badge_outlined,
              label: '신분증 전송하기',
              subtitle: docs?.hasIdCard == true
                  ? '등록된 신분증 보내기'
                  : '내정보에서 먼저 등록 필요',
              enabled: true,
            ),
          ];

    if (!mounted) return;
    final picked = await showChatAttachmentPickerSheet(
      context,
      options: options,
    );
    if (!mounted || picked == null) return;

    switch (picked) {
      case 'photo':
        await _sendPhoto();
      case 'resume':
        await _sendResume();
      case 'bank':
        await _sendRegisteredDocument(isIdCard: false);
      case 'id':
        await _sendRegisteredDocument(isIdCard: true);
    }
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

  Future<void> _openJobPost() async {
    final app = _application;
    if (app == null) return;

    var post = _jobPost ?? await _postsSource.findById(app.postId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고를 찾을 수 없습니다.')),
      );
      return;
    }

    if (_isEmployer && _jobPost == null) {
      setState(() => _jobPost = post);
    }

    if (_isEmployer) {
      await showCorporateJobPostPreviewSheet(context, post);
      return;
    }

    final pin = jobMapPinFromPost(post);
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) => JobPostDetailSheet(
        pin: pin,
        onClose: () => Navigator.of(sheetContext).pop(),
        onApply: () {
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _registerPermanentHire() async {
    final app = _application;
    if (app == null) return;

    final record = await showRegisterPermanentHireSheet(context, app);
    if (!mounted || record == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${record.seekerName}님 상시직 등록이 완료되었습니다.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _showsWorkAgreementUi =>
      ProductFeatureFlags.isHiringCommissionEnabled;

  bool get _canConfirmAgreement {
    if (!_showsWorkAgreementUi) return false;
    final app = _application;
    if (app == null || app.isWorkAgreementComplete) return false;
    if (_isEmployer) return app.employerWorkAgreedAt == null;
    return app.seekerWorkAgreedAt == null;
  }

  bool get _awaitingPeerAgreement {
    if (!_showsWorkAgreementUi) return false;
    final app = _application;
    if (app == null || app.isWorkAgreementComplete) return false;
    if (_isEmployer) {
      return app.employerWorkAgreedAt != null &&
          app.seekerWorkAgreedAt == null;
    }
    return app.seekerWorkAgreedAt != null &&
        app.employerWorkAgreedAt == null;
  }

  Future<void> _leaveChat() async {
    final app = _application;
    if (app == null) return;
    final left = await ChatRoomLeaveService.confirmAndLeave(
      context,
      applicationId: widget.applicationId,
      roomTitle: _isEmployer ? app.seekerName : app.companyName,
      roomSubtitle: '「${app.postTitle}」',
    );
    if (left && mounted) Navigator.of(context).pop(true);
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

    final showContactNotice = _isEmployer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: Text(_isEmployer ? app.seekerName : app.companyName),
        actions: [
          if (_showsWorkAgreementUi && _canConfirmAgreement && !app.isPermanentEmployment)
            TextButton(
              onPressed: _confirmWorkSchedule,
              child: const Text('근무예정 합의'),
            ),
          if (_showsWorkAgreementUi && _awaitingPeerAgreement)
            TextButton(
              onPressed: null,
              child: const Text('합의 대기'),
            ),
          if (_isEmployer &&
              app.isPermanentEmployment &&
              ProductFeatureFlags.isPermanentHireEnabled)
            TextButton(
              onPressed: _registerPermanentHire,
              child: const Text('상시직 합격'),
            ),
          ChatRoomLeaveMenu(
            useHamburgerIcon: true,
            iconColor: AppColors.textPrimary,
            onLeave: _leaveChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            child: InkWell(
              onTap: _openJobPost,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '「${app.postTitle}」 · ${app.workSchedule}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '공고 보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                    if (showContactNotice)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '연락처: ${app.seekerPhoneMasked} · 채팅·위치·사용 로그로 어뷰징 감시',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showsWorkAgreementUi && !app.isWorkAgreementComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: AppColors.primaryLight.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '근무예정 합의',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '구직자·구인자 모두 확인하면 근태 탭에 등록됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _canConfirmAgreement ? _confirmWorkSchedule : null,
                    child: Text(
                      _canConfirmAgreement
                          ? (_isEmployer
                              ? '기업 — 근무예정 합의하기'
                              : '구직자 — 근무예정 합의하기')
                          : _awaitingPeerAgreement
                              ? '상대방 합의 대기 중'
                              : '합의 완료 처리 중',
                    ),
                  ),
                ],
              ),
            )
          else if (_showsWorkAgreementUi && app.isWorkAgreementComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE8F5E9),
              child: const Text(
                '근무예정 합의 완료 · 근태 탭에서 출근을 확인하세요',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final fromSelf = (_isEmployer && msg.fromEmployer) ||
                    (!_isEmployer && !msg.fromEmployer);
                return ChatMessageBubble(
                  message: msg,
                  fromSelf: fromSelf,
                  applicationId: widget.applicationId,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '첨부',
                    onPressed: _openAttachmentPicker,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (_isEmployer) ...[
                    IconButton(
                      tooltip: '자주 쓰는 답변',
                      onPressed: _openMacroPicker,
                      icon: const ChatReplyMacroIcon(size: 26),
                      color: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: '메시지 입력 (카카오·외부링크 유도 금지)',
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

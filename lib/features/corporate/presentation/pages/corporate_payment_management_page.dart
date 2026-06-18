import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_org_member.dart';
import 'package:map/features/corporate/domain/entities/corporate_org_role.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/entities/payment_delegation.dart';
import 'package:map/features/corporate/domain/entities/payment_delegation_status.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_fulfillment_service.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_request_service.dart';
import 'package:map/features/corporate/domain/services/saved_payment_method_service.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_args.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/corporate/presentation/widgets/payment/saved_card_register_dialog.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';
/// 결제 권한자 — 미결제 수수료·위임·조직 구성원 관리
class CorporatePaymentManagementPage extends StatefulWidget {
  const CorporatePaymentManagementPage({super.key});

  @override
  State<CorporatePaymentManagementPage> createState() =>
      _CorporatePaymentManagementPageState();
}

class _CorporatePaymentManagementPageState
    extends State<CorporatePaymentManagementPage> {
  bool _loading = true;
  List<HiringApplication> _pending = [];
  List<CorporateOrgMember> _members = [];
  List<PaymentDelegation> _delegations = [];
  List<SavedPaymentMethod> _savedCards = [];
  List<JobPostPaymentRequest> _jobPaymentRequests = [];
  bool _isFounder = false;
  bool _isPaymentAuthority = false;
  String? _companyKey;
  String? _myEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = AuthSession.instance.currentUser;
    final profile = user?.corporateProfile;
    final email = user?.email ?? '';
    final companyKey = profile?.companyKey;

    if (companyKey == null || companyKey.isEmpty || email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _companyKey = companyKey;
        _myEmail = email;
      });
      return;
    }

    final orgRepo = await CorporateOrganizationRepository.create();
    final hiringRepo = await LocalHiringRepository.create();
    final members = await orgRepo.listMembers(companyKey);
    final delegations = await orgRepo.listDelegations(companyKey);
    final pending = ProductFeatureFlags.isHiringCommissionEnabled
        ? await hiringRepo.fetchPendingCommissionsForPayer(email)
        : const <HiringApplication>[];
    final savedCards =
        await SavedPaymentMethodService().listForCompany(companyKey);
    final jobRequests =
        await JobPostPaymentRequestService().listPendingForPayer(
      companyKey: companyKey,
      payerEmail: email,
    );
    final founder = await orgRepo.isFounder(companyKey: companyKey, email: email);
    final me = await orgRepo.findMember(companyKey: companyKey, email: email);

    if (!mounted) return;
    setState(() {
      _companyKey = companyKey;
      _myEmail = email;
      _members = members;
      _delegations = delegations;
      _pending = pending;
      _savedCards = savedCards;
      _jobPaymentRequests = jobRequests;
      _isFounder = founder;
      _isPaymentAuthority = me?.isPaymentAuthority ?? false;
      _loading = false;
    });
  }

  Future<void> _registerCard() async {
    final key = _companyKey;
    final email = _myEmail;
    if (key == null || email == null) return;
    final draft = await showSavedCardRegisterDialog(context);
    if (draft == null || !mounted) return;
    try {
      await SavedPaymentMethodService().registerMockCard(
        companyKey: key,
        registeredByEmail: email,
        cardBrand: draft.cardBrand,
        last4: draft.last4,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카드가 등록되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카드 등록에 실패했습니다.')),
      );
    }
  }

  Future<void> _removeCard(SavedPaymentMethod card) async {
    final key = _companyKey;
    if (key == null) return;
    final ok = await SavedPaymentMethodService().removeCard(
      companyKey: key,
      id: card.id,
    );
    if (!mounted) return;
    if (ok) await _load();
  }

  Future<void> _setDefaultCard(SavedPaymentMethod card) async {
    final key = _companyKey;
    if (key == null) return;
    final ok = await SavedPaymentMethodService().setDefault(
      companyKey: key,
      id: card.id,
    );
    if (!mounted) return;
    if (ok) await _load();
  }

  Future<void> _payJobRequest(JobPostPaymentRequest request) async {
    final result = await Navigator.of(context).pushNamed<PaymentCompletionResult>(
      AppRoutes.corporateNotificationPayment,
      arguments: CorporateNotificationPaymentArgs(
        bundle: request.bundle,
        paymentRequestId: request.id,
        paymentKind: request.kind,
      ),
    );
    if (result == null || !mounted) return;
    final fulfillment =
        await JobPostPaymentFulfillmentService().fulfillAfterPayment(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fulfillment),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _pay(HiringApplication app) async {
    final paid = await showCommissionPaymentDialog(context, app);
    if (paid == true && mounted) await _load();
  }

  Future<void> _assignPaymentAuthority(CorporateOrgMember member) async {
    final key = _companyKey;
    final email = _myEmail;
    if (key == null || email == null) return;
    final orgRepo = await CorporateOrganizationRepository.create();
    final ok = await orgRepo.assignPaymentAuthorityRole(
      companyKey: key,
      actorEmail: email,
      targetEmail: member.email,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${member.displayLabel}님을 결제 권한자로 지정했습니다.'
              : '결제 권한자 지정에 실패했습니다.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) await _load();
  }

  Future<void> _requestDelegation({
    required String recruiterEmail,
    required String payerEmail,
  }) async {
    final key = _companyKey;
    final email = _myEmail;
    if (key == null || email == null) return;
    try {
      final orgRepo = await CorporateOrganizationRepository.create();
      await orgRepo.requestDelegation(
        companyKey: key,
        recruiterEmail: recruiterEmail,
        payerEmail: payerEmail,
        requestedByEmail: email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결제 위임 요청을 보냈습니다. 상대방 승인을 기다려 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } on StateError catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'payer_not_authorized' => '결제 권한자로 등록된 구성원만 선택할 수 있습니다.',
        'same_party' => '본인에게는 위임할 수 없습니다.',
        _ => '위임 요청에 실패했습니다.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _respondDelegation(PaymentDelegation d, bool accept) async {
    final key = _companyKey;
    final email = _myEmail;
    if (key == null || email == null) return;
    final orgRepo = await CorporateOrganizationRepository.create();
    final result = await orgRepo.respondDelegation(
      companyKey: key,
      recruiterEmail: d.recruiterEmail,
      payerEmail: d.payerEmail,
      responderEmail: email,
      accept: accept,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? '처리할 수 없습니다.'
              : accept
                  ? '결제 위임을 승인했습니다.'
                  : '결제 위임을 거절했습니다.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _bulkDelegateToMe() async {
    final key = _companyKey;
    final email = _myEmail;
    if (key == null || email == null || !_isPaymentAuthority) return;

    final recruiters = _members
        .where((m) => m.email.trim().toLowerCase() != email.trim().toLowerCase())
        .map((m) => m.email)
        .toList();
    if (recruiters.isEmpty) return;

    final orgRepo = await CorporateOrganizationRepository.create();
    final results = await orgRepo.bulkRequestDelegation(
      companyKey: key,
      payerEmail: email,
      requestedByEmail: email,
      recruiterEmails: recruiters,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${results.length}명에게 결제 위임 요청을 보냈습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  List<PaymentDelegation> get _pendingDelegations => _delegations
      .where((d) => d.status == PaymentDelegationStatus.pending)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text(
          '결제 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (_companyKey == null) ...[
                    const Text('기업 프로필을 먼저 등록해 주세요.'),
                  ] else ...[
                    _sectionTitle('등록 카드'),
                    if (_savedCards.isEmpty)
                      _emptyHint('등록된 카드가 없습니다. 카드를 등록하면 결제가 더 빠릅니다.')
                    else
                      ..._savedCards.map(_savedCardTile),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _registerCard,
                        icon: const Icon(Icons.add_card_outlined, size: 18),
                        label: const Text('카드 등록'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('공고 결제 요청'),
                    if (_jobPaymentRequests.isEmpty)
                      _emptyHint('대기 중인 공고 결제 요청이 없습니다.')
                    else
                      ..._jobPaymentRequests.map(_jobPaymentRequestTile),
                    const SizedBox(height: 20),
                    if (ProductFeatureFlags.isHiringCommissionEnabled) ...[
                      _sectionTitle('미결제 수수료'),
                      if (_pending.isEmpty)
                        _emptyHint('결제 대기 중인 수수료가 없습니다.')
                      else
                        ..._pending.map(_pendingTile),
                      const SizedBox(height: 20),
                    ] else ...[
                      _emptyHint(
                        '일자리 알림핀·정류장 표시핀·PUSH 결제는 '
                        '공고 작성·수정 화면 하단 「유료 서비스」에서 이용해 주세요.',
                      ),
                      const SizedBox(height: 20),
                    ],
                    _sectionTitle('조직 구성원 (동일 사업자번호)'),
                    if (_members.isEmpty)
                      _emptyHint('같은 사업자등록번호로 가입한 담당자가 없습니다.')
                    else
                      ..._members.map(_memberTile),
                    const SizedBox(height: 20),
                    _sectionTitle('결제 위임'),
                    if (_isPaymentAuthority) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _bulkDelegateToMe,
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('전체 채용 담당자에게 위임 요청'),
                        ),
                      ),
                    ],
                    if (_pendingDelegations.isEmpty)
                      _emptyHint('대기 중인 위임 요청이 없습니다.')
                    else
                      ..._pendingDelegations.map(_delegationTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _savedCardTile(SavedPaymentMethod card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Row(
          children: [
            const Icon(Icons.credit_card_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.displayLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (card.isDefault)
                    Text(
                      '기본 결제수단',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
            if (!card.isDefault)
              TextButton(
                onPressed: () => _setDefaultCard(card),
                child: const Text('기본'),
              ),
            IconButton(
              onPressed: () => _removeCard(card),
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }

  String _requesterLabel(JobPostPaymentRequest request) {
    final stored = request.requesterDisplayName?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    for (final member in _members) {
      if (member.email.trim().toLowerCase() ==
          request.requesterEmail.trim().toLowerCase()) {
        return member.displayLabel;
      }
    }
    return request.requesterEmail;
  }

  Widget _jobPaymentRequestTile(JobPostPaymentRequest request) {
    final amount = request.amountKrw.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final requester = _requesterLabel(request);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.jobTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.productLabel} · ${amount}원',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            Text(
              '요청: $requester',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _payJobRequest(request),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('결제하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingTile(HiringApplication app) {
    final amount = CommissionCalculator.forApplication(app);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.postTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${app.seekerName} · ${CommissionCalculator.formatKrw(amount)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  if (app.recruiterEmail != null &&
                      app.recruiterEmail!.trim().isNotEmpty &&
                      app.recruiterEmail!.trim().toLowerCase() !=
                          (_myEmail ?? '').trim().toLowerCase())
                    Text(
                      '채용 담당: ${app.recruiterEmail}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _pay(app),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('결제'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(CorporateOrgMember member) {
    final isMe = member.email.trim().toLowerCase() ==
        (_myEmail ?? '').trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: member.isPaymentAuthority
                        ? AppColors.primaryLight.withValues(alpha: 0.35)
                        : AppColors.searchBarBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.role.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: member.isPaymentAuthority
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (_isFounder && !isMe && !member.isPaymentAuthority) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _assignPaymentAuthority(member),
                  child: const Text('결제 권한자로 지정'),
                ),
              ),
            ],
            if (!isMe && _myEmail != null) ...[
              if (!member.isPaymentAuthority && _isPaymentAuthority) ...[
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () => _requestDelegation(
                    recruiterEmail: member.email,
                    payerEmail: _myEmail!,
                  ),
                  child: Text('${member.displayLabel} 결제 위임 요청'),
                ),
              ] else if (member.isPaymentAuthority && !_isPaymentAuthority) ...[
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () => _requestDelegation(
                    recruiterEmail: _myEmail!,
                    payerEmail: member.email,
                  ),
                  child: Text('${member.name}에게 결제 위임 요청'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _delegationTile(PaymentDelegation d) {
    final email = _myEmail ?? '';
    final isResponder = email.trim().toLowerCase() !=
        d.requestedByEmail.trim().toLowerCase();
    final canRespond = isResponder &&
        (email.trim().toLowerCase() == d.recruiterEmail.trim().toLowerCase() ||
            email.trim().toLowerCase() == d.payerEmail.trim().toLowerCase());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.recruiterEmail} → ${d.payerEmail}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              d.status.label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            if (canRespond) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _respondDelegation(d, true),
                    child: const Text('승인'),
                  ),
                  TextButton(
                    onPressed: () => _respondDelegation(d, false),
                    child: const Text('거절'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

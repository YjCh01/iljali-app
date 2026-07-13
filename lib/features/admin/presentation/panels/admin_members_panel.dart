import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_company_verification_card.dart';
import 'package:map/features/admin/presentation/widgets/admin_shuttle_route_import_card.dart';
import 'package:map/features/admin/presentation/widgets/admin_credit_stepper.dart';
import 'package:map/features/admin/presentation/widgets/admin_sanction_card.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

enum _MemberTab { corporate, employer, seeker }

enum _CorporateSort { brn, companyName, joined }

enum _EmployerSort { joined, name, companyName, brn }

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  final _searchCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyKeyCtrl = TextEditingController();

  int _recruitmentPinGrant = 1;
  int _shuttleStopPinGrant = 1;
  int _pushTicketGrant = 1;

  _MemberTab _tab = _MemberTab.corporate;
  _CorporateSort _corporateSort = _CorporateSort.brn;
  _EmployerSort _employerSort = _EmployerSort.joined;

  List<Map<String, dynamic>> _companies = const [];
  List<Map<String, dynamic>> _employers = const [];
  List<Map<String, dynamic>> _seekers = const [];
  Map<String, dynamic>? _selectedMember;
  String? _selectedCompanyKey;
  String? _selectedCompanyName;
  Map<String, dynamic>? _wallet;
  final Set<String> _expandedCompanies = {};
  String? _error;
  bool _loading = false;

  static const _roleOrder = [
    'payment_authority',
    'head_office_admin',
    'branch_admin',
    'recruiter',
  ];

  static const _roleLabels = {
    'payment_authority': '결제관리자',
    'head_office_admin': '본사관리자',
    'branch_admin': '지점관리자',
    'recruiter': '채용담당자',
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _searchCtrl.dispose();
    _emailCtrl.dispose();
    _companyKeyCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  String get _corporateSortKey => switch (_corporateSort) {
        _CorporateSort.brn => 'brn',
        _CorporateSort.companyName => 'company_name',
        _CorporateSort.joined => 'joined',
      };

  String get _employerSortKey => switch (_employerSort) {
        _EmployerSort.joined => 'joined',
        _EmployerSort.name => 'name',
        _EmployerSort.companyName => 'company_name',
        _EmployerSort.brn => 'brn',
      };

  Future<void> _load() async {
    if (!widget.controller.apiReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tab == _MemberTab.corporate) {
        final body = await widget.controller.client.getCorporateDirectory(
          query: _searchCtrl.text.trim(),
          sort: _corporateSortKey,
        );
        final list = body['companies'] as List<dynamic>? ?? [];
        if (!mounted) return;
        setState(() {
          _companies = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      } else if (_tab == _MemberTab.employer) {
        final body = await widget.controller.client.getEmployerDirectory(
          query: _searchCtrl.text.trim(),
          sort: _employerSortKey,
        );
        final list = body['members'] as List<dynamic>? ?? [];
        if (!mounted) return;
        setState(() {
          _employers = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      } else {
        final list = await widget.controller.client.searchMembers(
          query: _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          limit: 200,
        );
        if (!mounted) return;
        setState(() {
          _seekers = list
              .where((m) => '${m['member_type']}' == 'seeker')
              .toList();
          _loading = false;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminApiErrors.format(e);
        _loading = false;
      });
    }
  }

  Future<void> _seedEmployers() async {
    await widget.controller.run(
      () => widget.controller.client.seedEmployers(),
      successMessage: '구인자 샘플 등록 완료',
    );
    await _load();
  }

  void _selectCompany(Map<String, dynamic> company) {
    final key = '${company['company_key']}';
    _companyKeyCtrl.text = key;
    setState(() {
      _selectedCompanyKey = key;
      _selectedCompanyName = '${company['company_name'] ?? key}';
    });
    _loadWallet();
  }

  void _selectMember(Map<String, dynamic> member) {
    _emailCtrl.text = '${member['email']}';
    final companyKey = '${member['company_key'] ?? ''}';
    if (companyKey.isNotEmpty) {
      _companyKeyCtrl.text = companyKey;
    }
    setState(() {
      _selectedMember = member;
      if (companyKey.isNotEmpty) {
        _selectedCompanyKey = companyKey;
        _selectedCompanyName = '${member['company_name'] ?? companyKey}';
      }
    });
    if (companyKey.isNotEmpty) {
      _loadWallet();
    }
  }

  Future<void> _loadWallet() async {
    final key = _companyKeyCtrl.text.trim();
    if (key.isEmpty || !widget.controller.apiReady) return;
    await widget.controller.run(
      () async {
        _wallet = await widget.controller.client.getWallet(key);
      },
      successMessage: '이용권 잔액 조회',
    );
    if (mounted) setState(() {});
  }

  Future<void> _grantWallet() async {
    final key = _companyKeyCtrl.text.trim();
    if (key.isEmpty) return;
    if (_recruitmentPinGrant <= 0 &&
        _shuttleStopPinGrant <= 0 &&
        _pushTicketGrant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('부여할 수량을 1개 이상 선택해 주세요.')),
      );
      return;
    }
    await widget.controller.run(
      () => widget.controller.client.grantWallet(
        companyKey: key,
        packageCredits: _recruitmentPinGrant,
        shuttleStopCredits: _shuttleStopPinGrant,
        pushTicketCredits: _pushTicketGrant,
      ),
      successMessage: '이용권 부여 완료',
    );
    await _loadWallet();
  }

  void _toggleCompanyExpanded(String key) {
    setState(() {
      if (_expandedCompanies.contains(key)) {
        _expandedCompanies.remove(key);
      } else {
        _expandedCompanies.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    if (!c.apiReady) {
      return const AdminPanelScroll(
        child: Text('API 미설정 — Admin 실행.command 로 실행하세요.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _buildLeftPanel(c),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: _buildRightPanel(c),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(AdminOpsController c) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EAED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SegmentedButton<_MemberTab>(
                    segments: const [
                      ButtonSegment(
                        value: _MemberTab.corporate,
                        label: Text('기업회원'),
                        icon: Icon(Icons.business_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: _MemberTab.employer,
                        label: Text('구인자회원'),
                        icon: Icon(Icons.badge_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: _MemberTab.seeker,
                        label: Text('구직자'),
                        icon: Icon(Icons.person_outline, size: 18),
                      ),
                    ],
                    selected: {_tab},
                onSelectionChanged: (s) {
                  setState(() => _tab = s.first);
                  _load();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: '검색',
                        hintText: '이름 · 전화 · 이메일 · 사업자번호 · 지점',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('검색'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    switch (_tab) {
                      _MemberTab.corporate => '기업 ${_companies.length}곳',
                      _MemberTab.employer => '구인자 ${_employers.length}명',
                      _MemberTab.seeker => '구직자 ${_seekers.length}명',
                    },
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (_tab == _MemberTab.corporate)
                    DropdownButton<_CorporateSort>(
                      value: _corporateSort,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: _CorporateSort.brn,
                          child: Text('사업자번호순'),
                        ),
                        DropdownMenuItem(
                          value: _CorporateSort.companyName,
                          child: Text('기업 ㄱㄴㄷ순'),
                        ),
                        DropdownMenuItem(
                          value: _CorporateSort.joined,
                          child: Text('가입순'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _corporateSort = v);
                        _load();
                      },
                    )
                  else if (_tab == _MemberTab.employer)
                    DropdownButton<_EmployerSort>(
                      value: _employerSort,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: _EmployerSort.joined,
                          child: Text('가입순'),
                        ),
                        DropdownMenuItem(
                          value: _EmployerSort.name,
                          child: Text('이름순'),
                        ),
                        DropdownMenuItem(
                          value: _EmployerSort.companyName,
                          child: Text('기업명순'),
                        ),
                        DropdownMenuItem(
                          value: _EmployerSort.brn,
                          child: Text('사업자번호순'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _employerSort = v);
                        _load();
                      },
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
                ),
              ),
            Expanded(
              child: switch (_tab) {
                _MemberTab.corporate => _buildCorporateTree(),
                _MemberTab.employer => _buildEmployerList(),
                _MemberTab.seeker => _buildSeekerList(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorporateTree() {
    if (_companies.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('등록된 기업회원이 없습니다'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.controller.apiConnected &&
                      !widget.controller.busy
                  ? _seedEmployers
                  : null,
              child: const Text('샘플 구인자·기업 등록'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      itemCount: _companies.length,
      itemBuilder: (context, i) {
        final company = _companies[i];
        final key = '${company['company_key']}';
        final expanded = _expandedCompanies.contains(key);
        final roles = Map<String, dynamic>.from(
          company['roles'] as Map? ?? {},
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: _selectedCompanyKey == key
              ? AppColors.primary.withValues(alpha: 0.06)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: _selectedCompanyKey == key
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : const Color(0xFFE8EAED),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  expanded ? Icons.folder_open : Icons.folder,
                  color: AppColors.primary,
                ),
                title: Text(
                  '${company['company_name'] ?? key}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'BRN $key · ${company['member_count'] ?? 0}명 · 탭=선택',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  tooltip: expanded ? '접기' : '펼치기',
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => _toggleCompanyExpanded(key),
                ),
                onTap: () => _selectCompany(company),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(
                    children: [
                      for (final roleKey in _roleOrder)
                        _roleFolder(
                          roleKey: roleKey,
                          members: (roles[roleKey] as List<dynamic>? ?? [])
                              .map((e) =>
                                  Map<String, dynamic>.from(e as Map))
                              .toList(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleFolder({
    required String roleKey,
    required List<Map<String, dynamic>> members,
  }) {
    if (members.isEmpty) return const SizedBox.shrink();
    final label = _roleLabels[roleKey] ?? roleKey;

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const Icon(Icons.folder_shared_outlined, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text('${members.length}명', style: const TextStyle(fontSize: 11)),
      children: [
        for (final m in members)
          ListTile(
            dense: true,
            selected: _selectedMember?['email'] == m['email'],
            title: Text('${m['display_name'] ?? m['email']}'),
            subtitle: Text(
              '${m['phone'] ?? ''} · ${m['email']}',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _selectMember(m),
          ),
      ],
    );
  }

  Widget _buildSeekerList() {
    if (_seekers.isEmpty && !_loading) {
      return const Center(child: Text('등록된 구직자가 없습니다'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _seekers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = _seekers[i];
        final selected = _selectedMember?['email'] == m['email'];
        return ListTile(
          selected: selected,
          title: Text(
            '${m['display_name'] ?? m['email']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${m['email']}\n가입 ${_formatDate('${m['created_at'] ?? ''}')}',
            style: const TextStyle(fontSize: 11, height: 1.35),
          ),
          isThreeLine: true,
          onTap: () => _selectMember(m),
        );
      },
    );
  }

  Widget _buildEmployerList() {
    if (_employers.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('등록된 구인자가 없습니다'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.controller.apiConnected &&
                      !widget.controller.busy
                  ? _seedEmployers
                  : null,
              child: const Text('샘플 구인자 등록'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _employers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = _employers[i];
        final selected = _selectedMember?['email'] == m['email'];
        return ListTile(
          selected: selected,
          title: Text(
            '${m['display_name'] ?? m['email']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${m['org_role_label'] ?? ''} · ${m['company_name'] ?? ''}\n'
            '${m['phone'] ?? ''} · ${m['email']}',
            style: const TextStyle(fontSize: 11, height: 1.35),
          ),
          isThreeLine: true,
          onTap: () => _selectMember(m),
        );
      },
    );
  }

  Widget _buildRightPanel(AdminOpsController c) {
    final m = _selectedMember;
    final hasCompany = (_selectedCompanyKey ?? '').isNotEmpty;

    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (m == null && !hasCompany)
            AdminCard(
              title: '회원·이용권 처리',
              subtitle: '왼쪽에서 기업 또는 구인자를 선택하세요',
              child: Text(
                '기업 선택 → 알림핀·정류장·PUSH 부여 · 구인자 선택 → 제재 처리',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (hasCompany) ...[
            AdminCard(
              title: '기업 이용권 · 핀',
              subtitle: _selectedCompanyName ?? _selectedCompanyKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminField(
                    label: '사업자번호 (BRN)',
                    controller: _companyKeyCtrl,
                  ),
                  AdminCreditStepper(
                    label: '일자리 알림핀',
                    subtitle: '근무지·모집지역 노출 · PUSH 발송',
                    value: _recruitmentPinGrant,
                    onChanged: (v) => setState(() => _recruitmentPinGrant = v),
                  ),
                  AdminCreditStepper(
                    label: '정류장 표시핀',
                    subtitle: '셔틀 정류장 지도 노출',
                    value: _shuttleStopPinGrant,
                    onChanged: (v) => setState(() => _shuttleStopPinGrant = v),
                  ),
                  AdminCreditStepper(
                    label: 'PUSH 알림권',
                    subtitle: '알림핀·정류장 1곳 PUSH 1회',
                    value: _pushTicketGrant,
                    onChanged: (v) => setState(() => _pushTicketGrant = v),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: !c.apiReady || c.busy ? null : _grantWallet,
                        child: const Text('선택 수량 부여'),
                      ),
                      OutlinedButton(
                        onPressed: !c.apiReady || c.busy ? null : _loadWallet,
                        child: const Text('잔액 조회'),
                      ),
                    ],
                  ),
                  if (_wallet != null) ...[
                    const SizedBox(height: 12),
                    _WalletSummary(data: _wallet!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AdminCompanyVerificationCard(
              key: ValueKey('verify-${_selectedCompanyKey!}'),
              companyKey: _selectedCompanyKey!,
              companyName: _selectedCompanyName,
              registeredOnServer: true,
            ),
            const SizedBox(height: 12),
            AdminShuttleRouteImportCard(
              key: ValueKey('shuttle-import-${_selectedCompanyKey!}'),
              controller: c,
              companyKey: _selectedCompanyKey!,
              companyName: _selectedCompanyName,
            ),
            const SizedBox(height: 12),
          ],
          if (m != null) ...[
            AdminCard(
              title: '${m['display_name'] ?? m['email']}',
              subtitle: '${m['org_role_label'] ?? m['member_type']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailRow('이메일', '${m['email']}'),
                  _detailRow('전화', '${m['phone'] ?? '-'}'),
                  _detailRow('기업', '${m['company_name'] ?? '-'}'),
                  _detailRow('사업자번호', '${m['company_key'] ?? '-'}'),
                  if ('${m['branch_name'] ?? ''}'.isNotEmpty)
                    _detailRow('지점', '${m['branch_name']}'),
                  if ('${m['department'] ?? ''}'.isNotEmpty)
                    _detailRow('부서', '${m['department']}'),
                  _detailRow(
                    '상태',
                    m['is_permanently_banned'] == true
                        ? '영구제재'
                        : m['is_suspended'] == true
                            ? '정지'
                            : '정상',
                  ),
                  if (m['created_at'] != null)
                    _detailRow('가입', _formatDate('${m['created_at']}')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          AdminCard(
            title: '회원 제재',
            subtitle: m == null
                ? '회원을 선택하면 정책 기반 제재를 적용할 수 있습니다'
                : '${m['email']} · ${_memberKindLabel(m)}',
            child: _emailCtrl.text.trim().isEmpty
                ? const Text(
                    '왼쪽 목록에서 회원을 선택하세요.',
                    style: TextStyle(fontSize: 13),
                  )
                : AdminSanctionCard(
                    key: ValueKey(_emailCtrl.text.trim()),
                    controller: c,
                    email: _emailCtrl.text.trim(),
                    memberKind: _memberKindFor(m),
                    companyKey: _selectedCompanyKey,
                    onApplied: _load,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.length > 10 ? raw.substring(0, 10) : raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  String _memberKindFor(Map<String, dynamic>? member) {
    if (member == null) {
      return _tab == _MemberTab.seeker ? 'seeker' : 'employer';
    }
    return '${member['member_type']}' == 'seeker' ? 'seeker' : 'employer';
  }

  String _memberKindLabel(Map<String, dynamic> member) {
    return _memberKindFor(member) == 'seeker' ? '구직자' : '구인자(기업)';
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('일자리 알림핀(노출): ${data['package_credits']}'),
          Text('PUSH 알림권: ${data['push_ticket_credits'] ?? 0}'),
          Text('사용 가능 푸시: ${data['available_push_credits']}'),
          Text(
            '거점 슬롯: ${data['total_location_slots'] ?? data['location_slots_from_packages']}',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_shuttle_participants_card.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminPilotPanel extends StatefulWidget {
  const AdminPilotPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminPilotPanel> createState() => _AdminPilotPanelState();
}

class _AdminPilotPanelState extends State<AdminPilotPanel> {
  final _phoneCtrl = TextEditingController();
  final _companyKeyCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _routeIdCtrl = TextEditingController();
  final _routeNameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _candidates = const [];
  Map<String, dynamic>? _selectedCandidate;
  Map<String, dynamic>? _selectedShuttleOption;
  var _identityVerified = false;
  var _loading = true;
  var _searching = false;
  var _updatingScopeFields = false;
  String? _searchError;
  String _workStartTime = '';

  @override
  void initState() {
    super.initState();
    _companyKeyCtrl.addListener(_onScopeChanged);
    _routeIdCtrl.addListener(_onScopeChanged);
    _load();
  }

  @override
  void dispose() {
    _companyKeyCtrl.removeListener(_onScopeChanged);
    _routeIdCtrl.removeListener(_onScopeChanged);
    _phoneCtrl.dispose();
    _companyKeyCtrl.dispose();
    _companyNameCtrl.dispose();
    _routeIdCtrl.dispose();
    _routeNameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onScopeChanged() {
    if (_updatingScopeFields) return;
    if (mounted) setState(() {});
  }

  void _setScopeFields({
    String companyKey = '',
    String companyName = '',
    String routeId = '',
    String routeName = '',
  }) {
    _updatingScopeFields = true;
    _companyKeyCtrl.text = companyKey;
    _companyNameCtrl.text = companyName;
    _routeIdCtrl.text = routeId;
    _routeNameCtrl.text = routeName;
    _updatingScopeFields = false;
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final c = widget.controller;
    if (!c.apiReady) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final json = await c.client.getBusLocationTowerPilot();
      if (!mounted) return;
      if (_companyKeyCtrl.text.trim().isEmpty) {
        _setScopeFields(
          companyKey: json['company_key'] as String? ?? '',
          companyName: json['company_name'] as String? ?? '',
          routeId: json['route_id'] as String? ?? '',
          routeName: json['route_name'] as String? ?? '',
        );
      }
      setState(() {
        _config = json;
        _noteCtrl.text = json['note'] as String? ?? '';
        _workStartTime = json['work_start_time'] as String? ?? '';
        _loading = false;
      });
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchByPhone() async {
    final c = widget.controller;
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 4) {
      setState(() {
        _searchError = '휴대폰 번호 4자리 이상 입력해 주세요.';
        _candidates = const [];
        _selectedCandidate = null;
        _selectedShuttleOption = null;
        _identityVerified = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _candidates = const [];
      _selectedCandidate = null;
      _selectedShuttleOption = null;
      _identityVerified = false;
    });
    _setScopeFields();

    try {
      final body = await c.client.searchBusLocationTowerCandidates(phone: phone);
      if (!mounted) return;
      final list = body['candidates'] as List<dynamic>? ?? [];
      final candidates = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _candidates = candidates;
        _searching = false;
        if (candidates.isEmpty) {
          _searchError = '일치하는 개인회원이 없습니다.';
        }
      });
      if (candidates.length == 1) {
        _selectCandidate(candidates.first, resetVerification: false);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = AdminApiErrors.format(e);
      });
    }
  }

  Future<bool> _confirmWorkStartTimeIfNeeded() async {
    if (_workStartTime.trim().isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('근무 시작시간 확인'),
        content: Text(
          '근무 시작시간을 ${_workStartTime}으로 지정하시면, '
          '해당 시간에 통근버스가 근무지에 도착한 것으로 간주하여 '
          '버스 위치 추적을 중지합니다.\n\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _pickWorkStartTime() async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    final parts = _workStartTime.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: '근무 시작시간 지정',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _workStartTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _approve() async {
    final c = widget.controller;
    final candidate = _selectedCandidate;
    if (candidate == null || !_identityVerified) return;
    if (!await _confirmWorkStartTimeIfNeeded()) return;

    await c.run(
      () => c.client.setBusLocationTowerPilot(
        seekerEmail: '${candidate['email']}',
        enabled: true,
        companyKey: _companyKeyCtrl.text,
        companyName: _companyNameCtrl.text,
        routeId: _routeIdCtrl.text,
        routeName: _routeNameCtrl.text,
        note: _noteCtrl.text,
        workStartTime: _workStartTime,
      ),
      successMessage: '셔틀위치담당자 승인 완료',
    );
    if (!mounted) return;
    setState(() {
      _candidates = const [];
      _selectedCandidate = null;
      _selectedShuttleOption = null;
      _identityVerified = false;
      _phoneCtrl.clear();
    });
    await _load();
  }

  Future<void> _revoke() async {
    final c = widget.controller;
    await c.run(
      () => c.client.setBusLocationTowerPilot(
        seekerEmail: '${_config?['seeker_email'] ?? ''}',
        enabled: false,
        companyKey: '${_config?['company_key'] ?? ''}',
        companyName: '${_config?['company_name'] ?? ''}',
        routeId: '${_config?['route_id'] ?? ''}',
        routeName: '${_config?['route_name'] ?? ''}',
        note: _noteCtrl.text,
        workStartTime: _workStartTime,
      ),
      successMessage: '셔틀위치담당자 승인 해제',
    );
    await _load();
  }

  bool get _canApprove =>
      widget.controller.apiReady &&
      !widget.controller.busy &&
      _selectedCandidate != null &&
      _companyKeyCtrl.text.trim().isNotEmpty &&
      _routeIdCtrl.text.trim().isNotEmpty &&
      _identityVerified;

  void _selectCandidate(
    Map<String, dynamic> candidate, {
    bool resetVerification = true,
  }) {
    final options = _shuttleOptions(candidate);
    setState(() {
      _selectedCandidate = candidate;
      if (resetVerification) _identityVerified = false;
      if (options.length != 1) _selectedShuttleOption = null;
    });
    if (options.length == 1) {
      _applyShuttleOption(options.first);
    }
  }

  List<Map<String, dynamic>> _shuttleOptions(Map<String, dynamic> candidate) {
    final raw = candidate['shuttle_options'] as List<dynamic>? ?? const [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _applyShuttleOption(Map<String, dynamic> option) {
    _selectedShuttleOption = option;
    _setScopeFields(
      companyKey: '${option['company_key'] ?? ''}',
      companyName: '${option['company_name'] ?? ''}',
      routeId: '${option['route_id'] ?? ''}',
      routeName: '${option['route_name'] ?? option['route_id'] ?? ''}',
    );
  }

  Future<void> _saveWorkStartTime() async {
    final c = widget.controller;
    if (_config?['enabled'] != true) return;
    if (!await _confirmWorkStartTimeIfNeeded()) return;
    await c.run(
      () => c.client.setBusLocationTowerPilot(
        seekerEmail: '${_config?['seeker_email'] ?? ''}',
        enabled: true,
        companyKey: '${_config?['company_key'] ?? ''}',
        companyName: '${_config?['company_name'] ?? ''}',
        routeId: '${_config?['route_id'] ?? ''}',
        routeName: '${_config?['route_name'] ?? ''}',
        note: _noteCtrl.text,
        workStartTime: _workStartTime,
      ),
      successMessage: '근무 시작시간 저장 완료',
    );
    await _load();
  }

  Future<void> _stopToday() async {
    final c = widget.controller;
    await c.run(
      () => c.client.stopBusLocationTowerToday(),
      successMessage: '오늘 셔틀 위치 공유 중지',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final approved = _config?['enabled'] == true;
    final approvedEmail = '${_config?['seeker_email'] ?? ''}';

    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (approved && approvedEmail.isNotEmpty) ...[
            AdminCard(
              title: '현재 승인된 셔틀위치담당자',
              subtitle: '앱 더보기·채팅에 관제 메뉴가 표시됩니다.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ApprovedSummary(config: _config!),
                  const SizedBox(height: 12),
                  _WorkStartTimeField(
                    workStartTime: _workStartTime,
                    onPick: _pickWorkStartTime,
                    onClear: () => setState(() => _workStartTime = ''),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: !c.apiReady || c.busy ? null : _saveWorkStartTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _workStartTime.isEmpty
                          ? '근무 시작시간 저장'
                          : '근무 시작 $_workStartTime 저장',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: !c.apiReady || c.busy ? null : _stopToday,
                    icon: const Icon(Icons.location_off_outlined),
                    label: const Text('오늘 위치 공유 중지'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: !c.apiReady || c.busy ? null : _revoke,
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('승인 해제'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AdminCard(
            title: '셔틀위치담당자 지정',
            subtitle:
                '참여자 휴대폰 번호로 개인회원을 검색한 뒤, 본인 확인 후 승인합니다.',
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AdminField(
                              label: '참여자 휴대폰 번호',
                              controller: _phoneCtrl,
                              hint: '01012345678',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: FilledButton.tonalIcon(
                              onPressed:
                                  !c.apiReady || c.busy || _searching
                                      ? null
                                      : _searchByPhone,
                              icon: _searching
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: const Text('검색'),
                            ),
                          ),
                        ],
                      ),
                      if (_searchError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _searchError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_candidates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '검색 결과 (${_candidates.length}명)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._candidates.map(_buildCandidateTile),
                      ],
                      if (_selectedCandidate != null) ...[
                        const SizedBox(height: 12),
                        _buildShuttleScopeSelector(_selectedCandidate!),
                        const SizedBox(height: 12),
                        _WorkStartTimeField(
                          workStartTime: _workStartTime,
                          onPick: _pickWorkStartTime,
                          onClear: () => setState(() => _workStartTime = ''),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _identityVerified,
                          onChanged: c.busy
                              ? null
                              : (v) => setState(
                                    () => _identityVerified = v ?? false,
                                  ),
                          title: const Text(
                            '본인 확인 및 사전 협의 완료',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            '운영팀과 노선·일정 협의가 끝난 참여자인지 확인했습니다.',
                          ),
                        ),
                      ],
                      AdminField(
                        label: '운영 메모 (회원에게는 안 보임)',
                        controller: _noteCtrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _canApprove ? _approve : null,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('셔틀위치담당자 승인'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          AdminShuttleParticipantsCard(controller: c),
        ],
      ),
    );
  }

  Widget _buildCandidateTile(Map<String, dynamic> candidate) {
    final email = '${candidate['email']}';
    final selected = _selectedCandidate?['email'] == email;
    final locationOk = candidate['location_consent_granted'] == true;
    final phoneVerified = candidate['phone_verified'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primaryLight.withValues(alpha: 0.25)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.controller.busy
              ? null
              : () => _selectCandidate(candidate),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${candidate['display_name'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate['phone'] ?? '-'} · $email',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusChip(
                            label: locationOk ? '위치 동의 완료' : '위치 동의 필요',
                            ok: locationOk,
                          ),
                          _StatusChip(
                            label: phoneVerified ? '휴대폰 인증' : '휴대폰 미인증',
                            ok: phoneVerified,
                          ),
                        ],
                      ),
                      ..._buildCandidateShuttleOptions(candidate),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCandidateShuttleOptions(Map<String, dynamic> candidate) {
    final options = _shuttleOptions(candidate);
    if (options.isEmpty) {
      return [
        const SizedBox(height: 8),
        Text(
          '최근 서버에 동기화된 셔틀 선택 내역이 없습니다. 아래에서 회사·셔틀을 직접 입력하세요.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final selected =
              _selectedShuttleOption?['route_id'] == option['route_id'] &&
                  _selectedShuttleOption?['company_key'] ==
                      option['company_key'];
          final label = [
            option['company_name'] ?? option['company_key'] ?? '',
            option['route_name'] ?? option['route_id'] ?? '',
            option['shift_date'] ?? '',
          ].where((e) => '$e'.trim().isNotEmpty).join(' · ');
          return ChoiceChip(
            label: Text(label.isEmpty ? '셔틀 선택' : label),
            selected: selected,
            onSelected: widget.controller.busy
                ? null
                : (_) => _applyShuttleOption(option),
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildShuttleScopeSelector(Map<String, dynamic> candidate) {
    final name = '${candidate['display_name'] ?? '-'}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$name 담당 범위',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '아래 회사·셔틀을 오늘 선택한 근무자만 이 담당자의 위치를 볼 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AdminField(
                  label: '회사 사업자번호/키',
                  controller: _companyKeyCtrl,
                  hint: '5403100894',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminField(
                  label: '회사명',
                  controller: _companyNameCtrl,
                  hint: '아라컴퍼니',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: AdminField(
                  label: '셔틀 노선 ID',
                  controller: _routeIdCtrl,
                  hint: 'route_daiso_sejong',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdminField(
                  label: '셔틀 표시명',
                  controller: _routeNameCtrl,
                  hint: '세종 물류센터 1호차',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkStartTimeField extends StatelessWidget {
  const _WorkStartTimeField({
    required this.workStartTime,
    required this.onPick,
    required this.onClear,
  });

  final String workStartTime;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '근무 시작시간',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '지정 시 해당 시간에 통근버스가 근무지 도착으로 간주되어 위치 추적이 중지됩니다.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.access_time_rounded),
                label: Text(
                  workStartTime.isEmpty ? '근무 시작시간 지정' : workStartTime,
                ),
              ),
            ),
            if (workStartTime.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClear,
                tooltip: '시간 지우기',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ApprovedSummary extends StatelessWidget {
  const _ApprovedSummary({required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    final locationOk = config['location_consent_granted'] == true;
    final session = config['today_session'] as Map<String, dynamic>?;
    final sessionActive = session?['active'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${config['seeker_display_name'] ?? '-'}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${config['seeker_phone'] ?? '-'} · ${config['seeker_email'] ?? '-'}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${config['company_name'] ?? config['company_key'] ?? '-'} · '
          '${config['route_name'] ?? config['route_id'] ?? '-'}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatusChip(
              label: locationOk ? '위치 동의 완료' : '위치 동의 필요',
              ok: locationOk,
            ),
            _StatusChip(
              label: '오늘 탑승자 ${config['authorized_rider_count'] ?? 0}명',
              ok: true,
            ),
            _StatusChip(
              label: sessionActive ? '오늘 위치 공유 중' : '오늘 위치 대기',
              ok: sessionActive,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.primaryLight.withValues(alpha: 0.22)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ok ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

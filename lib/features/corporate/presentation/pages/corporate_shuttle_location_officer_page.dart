import 'package:flutter/material.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/data/datasources/corporate_applicant_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 고용주 — 셔틀위치담당자 지정을 어드민에 승인요청 (직접 지정은 어드민 전용).
class CorporateShuttleLocationOfficerPage extends StatefulWidget {
  const CorporateShuttleLocationOfficerPage({super.key});

  @override
  State<CorporateShuttleLocationOfficerPage> createState() =>
      _CorporateShuttleLocationOfficerPageState();
}

class _CorporateShuttleLocationOfficerPageState
    extends State<CorporateShuttleLocationOfficerPage> {
  final _client = IljariApiClient();

  List<CommuteRoute> _routes = [];
  List<CorporateApplicant> _applicants = [];
  CommuteRoute? _selectedRoute;
  CorporateApplicant? _selectedApplicant;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _requests = [];
  String _workStartTime = '';
  bool _loadingRoutes = true;
  bool _loadingStatus = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  String? get _companyKey =>
      AuthSession.instance.currentUser?.corporateProfile?.companyKey;

  Future<void> _loadRoutes() async {
    final companyKey = _companyKey;
    if (companyKey == null) {
      setState(() {
        _loadingRoutes = false;
        _error = '기업 로그인이 필요합니다.';
      });
      return;
    }
    final repo = await CommuteRouteRepository.create();
    final routes = await repo.loadForCompany(companyKey);
    final applicants =
        await const CorporateApplicantLocalDataSourceImpl().fetchApplicants();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _applicants = applicants;
      _loadingRoutes = false;
      if (routes.length == 1) {
        _selectedRoute = routes.first;
        _loadStatus();
      }
    });
  }

  Future<void> _loadStatus() async {
    final route = _selectedRoute;
    if (route == null) return;
    setState(() {
      _loadingStatus = true;
      _error = null;
    });
    try {
      final status = await _client.fetchShuttleLocationOfficer(routeId: route.id);
      final requests = await _client.fetchShuttleLocationOfficerRequests();
      if (!mounted) return;
      setState(() {
        _status = status;
        _requests = requests
            .where((r) => r['route_id'] == route.id)
            .toList()
          ..sort(
            (a, b) => (b['created_at'] as String? ?? '')
                .compareTo(a['created_at'] as String? ?? ''),
          );
        _workStartTime = status['work_start_time'] as String? ?? '';
        _loadingStatus = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStatus = false;
        _error = '조회에 실패했습니다: $e';
      });
    }
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
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      _workStartTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _sendRequest() async {
    final route = _selectedRoute;
    final applicant = _selectedApplicant;
    if (route == null) return;
    if (applicant == null || applicant.seekerEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지정할 담당자를 목록에서 선택해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _client.requestShuttleLocationOfficer(
        routeId: route.id,
        seekerEmail: applicant.seekerEmail!,
        seekerName: applicant.name,
        routeName: route.routeName,
        workStartTime: _workStartTime,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('어드민에 셔틀위치담당자 지정을 요청했습니다.')),
      );
      setState(() => _selectedApplicant = null);
      await _loadStatus();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status?['enabled'] == true;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text('셔틀위치담당자 지정 요청'),
      ),
      body: _loadingRoutes
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _routes.isEmpty
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '위치 공유 담당자 지정은 어드민 승인이 필요합니다. '
                      '아래에서 노선과 담당자를 골라 요청을 보내면, '
                      '어드민이 검토 후 승인해야 실제로 반영됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_routes.isEmpty)
                      const Text('먼저 통근 셔틀 노선을 등록해 주세요.')
                    else
                      CorporateSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '노선 선택',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<CommuteRoute>(
                              isExpanded: true,
                              value: _selectedRoute,
                              items: _routes
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.routeName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (route) {
                                setState(() {
                                  _selectedRoute = route;
                                  _status = null;
                                  _requests = [];
                                  _selectedApplicant = null;
                                  _workStartTime = '';
                                });
                                if (route != null) _loadStatus();
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_selectedRoute != null) ...[
                      if (_loadingStatus)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        CorporateSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                enabled
                                    ? '현재 지정된 담당자: ${_status?['seeker_email'] ?? ''}'
                                    : '지정된 담당자 없음',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              _ApplicantPicker(
                                applicants: _applicants,
                                selected: _selectedApplicant,
                                onSelected: (applicant) =>
                                    setState(() => _selectedApplicant = applicant),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickWorkStartTime,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '근무 시작시간 (선택)',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    _workStartTime.isEmpty ? '미지정' : _workStartTime,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _sendRequest,
                                  child: const Text('승인 요청 보내기'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_requests.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          CorporateSurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '요청 내역',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                ..._requests.map(
                                  (r) => _RequestRow(request: r),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
    );
  }
}

class _ApplicantPicker extends StatelessWidget {
  const _ApplicantPicker({
    required this.applicants,
    required this.selected,
    required this.onSelected,
  });

  final List<CorporateApplicant> applicants;
  final CorporateApplicant? selected;
  final ValueChanged<CorporateApplicant?> onSelected;

  @override
  Widget build(BuildContext context) {
    final withEmail =
        applicants.where((a) => (a.seekerEmail ?? '').isNotEmpty).toList();
    if (withEmail.isEmpty) {
      return const Text('지정할 수 있는 지원자가 아직 없습니다.');
    }
    return Autocomplete<CorporateApplicant>(
      displayStringForOption: (a) => '${a.name} (${a.seekerEmail})',
      optionsBuilder: (value) {
        if (value.text.isEmpty) return withEmail;
        final query = value.text.toLowerCase();
        return withEmail.where(
          (a) =>
              a.name.toLowerCase().contains(query) ||
              (a.seekerEmail ?? '').toLowerCase().contains(query),
        );
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        if (selected != null) {
          controller.text = '${selected!.name} (${selected!.seekerEmail})';
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '담당자 검색 (이름 또는 이메일)',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'pending';
    final (label, color) = switch (status) {
      'approved' => ('승인됨', const Color(0xFF2E7D32)),
      'rejected' => ('반려됨', const Color(0xFFC62828)),
      _ => ('검토 중', AppColors.primary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${request['seeker_name'] ?? request['seeker_email']}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

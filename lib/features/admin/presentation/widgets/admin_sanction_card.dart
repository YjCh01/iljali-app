import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

/// 정책 기반 제재 — 구인자(엄격) / 구직자(관대)
class AdminSanctionCard extends StatefulWidget {
  const AdminSanctionCard({
    super.key,
    required this.controller,
    required this.email,
    required this.memberKind,
    this.companyKey,
    this.onApplied,
  });

  final AdminOpsController controller;
  final String email;
  final String memberKind;
  final String? companyKey;
  final VoidCallback? onApplied;

  @override
  State<AdminSanctionCard> createState() => _AdminSanctionCardState();
}

class _AdminSanctionCardState extends State<AdminSanctionCard> {
  Map<String, dynamic>? _policy;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _history = const [];
  String? _violationCode;
  final _reasonCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '30');
  bool _permanent = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminSanctionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email != widget.email) {
      _load();
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.controller.apiReady || widget.email.isEmpty) return;
    setState(() => _loading = true);
    try {
      _policy ??= await widget.controller.client.getSanctionPolicy();
      final body =
          await widget.controller.client.getMemberSanctionStatus(widget.email);
      if (!mounted) return;
      setState(() {
        _status = Map<String, dynamic>.from(body['status'] as Map? ?? {});
        final list = body['history'] as List<dynamic>? ?? [];
        _history = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _violations {
    final kind = widget.memberKind == 'employer' ? 'employer' : 'seeker';
    final block = _policy?[kind] as Map<String, dynamic>? ?? {};
    return Map<String, dynamic>.from(block['violations'] as Map? ?? {});
  }

  String? get _selectedTier {
    if (_violationCode == null) return null;
    final v = _violations[_violationCode!] as Map?;
    return v?['tier'] as String?;
  }

  Map<String, dynamic>? get _tierMeasures {
    if (_selectedTier == null || _policy == null) return null;
    final kind = widget.memberKind == 'employer' ? 'employer' : 'seeker';
    final tiers = (_policy![kind] as Map?)?['tiers'] as Map?;
    return Map<String, dynamic>.from(tiers?[_selectedTier!] as Map? ?? {});
  }

  Future<void> _apply() async {
    if (_violationCode == null) return;
    await widget.controller.run(
      () => widget.controller.client.applyPolicySanction(
        email: widget.email,
        memberKind: widget.memberKind,
        violationCode: _violationCode!,
        reason: _reasonCtrl.text.trim(),
        days: int.tryParse(_daysCtrl.text),
        permanent: _permanent,
        companyKey: widget.companyKey,
      ),
      successMessage: '정책 제재 적용 완료',
    );
    await _load();
    widget.onApplied?.call();
  }

  Future<void> _lift() async {
    await widget.controller.run(
      () => widget.controller.client.liftSanction(
        email: widget.email,
        reason: _reasonCtrl.text.trim(),
      ),
      successMessage: '제재 해제',
    );
    await _load();
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tier = _status?['sanction_tier'] as String? ?? '';
    final warnings = _status?['warning_count'] ?? 0;

    return AdminCard(
      title: '제재 정책',
      subtitle: widget.memberKind == 'employer'
          ? '구인자(기업) — 엄격 적용 · 이의제기 ${ _policy?['appeal_days'] ?? 7}일'
          : '구직자 — 관대 적용 · No-show 자동 연동',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (_status != null) ...[
              _infoRow('현재 단계', tier.isEmpty ? '정상' : tier),
              _infoRow('누적 경고', '$warnings회'),
              if (_status!['appeal_until'] != null)
                _infoRow(
                  '이의제기 마감',
                  _fmt('${_status!['appeal_until']}'),
                ),
              if (_status!['admin_review_required'] == true)
                const Text(
                  '⚠ 관리자 검토 대상',
                  style: TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _violationCode,
              decoration: const InputDecoration(
                labelText: '위반 유형',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in _violations.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${(e.value as Map)['label']} (${(e.value as Map)['tier']})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _violationCode = v),
            ),
            if (_tierMeasures != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '적용 조치: ${_tierMeasures!['label'] ?? _selectedTier}\n'
                  '${_formatMeasures(_tierMeasures!)}',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
            AdminField(label: '상세 사유', controller: _reasonCtrl, maxLines: 2),
            if (_selectedTier == 'suspension') ...[
              AdminField(
                label: '정지 일수 (영구면 무시)',
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('영구 제재', style: TextStyle(fontSize: 13)),
                value: _permanent,
                onChanged: (v) => setState(() => _permanent = v ?? false),
              ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: !c.apiReady || c.busy || _violationCode == null
                      ? null
                      : _apply,
                  child: const Text('정책 제재 적용'),
                ),
                OutlinedButton(
                  onPressed: !c.apiReady || c.busy ? null : _lift,
                  child: const Text('제재 전체 해제'),
                ),
                TextButton(
                  onPressed: _load,
                  child: const Text('새로고침'),
                ),
              ],
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '제재 이력 (관리자 열람)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              for (final h in _history.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_fmt('${h['created_at']}')} · ${h['tier']} · '
                    '${h['reason']} (${h['source']})',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatMeasures(Map<String, dynamic> m) {
    final parts = <String>[];
    if (m['job_exposure_limit_days'] != null) {
      parts.add('공고 노출 ${m['job_exposure_limit_days']}일 제한');
    }
    if (m['apply_restriction_days'] != null) {
      parts.add('지원 ${m['apply_restriction_days']}일 제한');
    }
    if (m['push_limit'] == true) parts.add('푸시 제한');
    if (m['vault_limit'] == true) parts.add('보관함 제한');
    if (m['hide_all_posts'] == true) parts.add('공고 전체 숨김');
    if (m['no_refund'] == true) parts.add('환불 불가');
    if (m['education_popup'] == true) parts.add('교육 팝업');
    return parts.join(' · ');
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.length > 16 ? raw.substring(0, 16) : raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }
}

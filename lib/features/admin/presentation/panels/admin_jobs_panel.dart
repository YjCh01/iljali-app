import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_event_pins_card.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';

class AdminJobsPanel extends StatefulWidget {
  const AdminJobsPanel({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminJobsPanel> createState() => _AdminJobsPanelState();
}

class _AdminJobsPanelState extends State<AdminJobsPanel> {
  final _postIdCtrl = TextEditingController(text: 'qc_post_real_001');
  final _jsonCtrl = TextEditingController();
  final _urlTextCtrl = TextEditingController();
  final _companyKeyCtrl = TextEditingController(text: '5403100894');
  final _companyNameCtrl = TextEditingController(text: '아라컴퍼니');
  final _postedByEmailCtrl = TextEditingController();
  final _postedByNameCtrl = TextEditingController();
  var _activateJobPin = true;
  List<_PreviewJobRow> _previewRows = const [];
  List<Map<String, dynamic>> _lastUrlImportResults = const [];
  final Set<String> _selectedUrls = {};
  final Set<String> _importedUrls = {};
  var _previewing = false;

  @override
  void initState() {
    super.initState();
    _loadExampleJson();
    _urlTextCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadExampleJson() async {
    try {
      final raw = await rootBundle.loadString('assets/fixtures/jobs.example.json');
      _jsonCtrl.text = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } on Object {
      _jsonCtrl.text = '''[
  {
    "id": "qc_post_real_001",
    "title": "[QC] 물류센터 야간 보조",
    "company_name": "테스트기업 알파",
    "company_key": "1000000001",
    "warehouse_name": "경기도 이천시",
    "hourly_wage": "12,500원",
    "work_schedule": "22:00-06:00",
    "summary": "실기업 공고 샘플",
    "status": "recruiting"
  }
]''';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _postIdCtrl.dispose();
    _jsonCtrl.dispose();
    _urlTextCtrl.dispose();
    _companyKeyCtrl.dispose();
    _companyNameCtrl.dispose();
    _postedByEmailCtrl.dispose();
    _postedByNameCtrl.dispose();
    super.dispose();
  }

  int _countUrls(String text) {
    return text
        .split(RegExp(r'[\s,]+'))
        .where((part) {
          final trimmed = part.trim();
          return trimmed.startsWith('http://') || trimmed.startsWith('https://');
        })
        .length;
  }

  Future<void> _previewUrls(AdminOpsController c) async {
    setState(() => _previewing = true);
    try {
      final result = await c.run(
        () => c.client.previewImportJobUrls(urlText: _urlTextCtrl.text),
        successMessage: '공고 목록 불러오기 완료 (아직 DB 미등록)',
      );
      final raw = result['items'];
      if (!mounted || raw is! List) return;
      final rows = raw
          .whereType<Map>()
          .map((e) => _PreviewJobRow.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.url.isNotEmpty)
          .toList();
      setState(() {
        _previewRows = rows;
        _selectedUrls
          ..clear()
          ..addAll(rows.where((r) => r.ok).map((r) => r.url));
        _importedUrls.clear();
        _lastUrlImportResults = const [];
      });
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _importUrls(
    AdminOpsController c,
    List<String> urls, {
    required String successMessage,
  }) async {
    if (urls.isEmpty) return;
    final result = await c.run(
      () => c.client.bulkImportJobUrls(
        urls: urls,
        companyKey: _companyKeyCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        postedByEmail: _postedByEmailCtrl.text.trim(),
        postedByName: _postedByNameCtrl.text.trim(),
        activateJobPin: _activateJobPin,
      ),
      successMessage: successMessage,
    );
    final raw = result['results'];
    if (!mounted || raw is! List) return;
    final mapped =
        raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      _lastUrlImportResults = [...mapped, ..._lastUrlImportResults];
      for (final row in mapped) {
        final url = row['url']?.toString() ?? '';
        if (url.isNotEmpty && row['ok'] == true) {
          _importedUrls.add(url);
          _selectedUrls.remove(url);
        }
      }
    });
  }

  Future<void> _importSelected(AdminOpsController c) async {
    final urls = _selectedUrls
        .where((u) => !_importedUrls.contains(u))
        .toList(growable: false);
    await _importUrls(
      c,
      urls,
      successMessage: '선택한 ${urls.length}건 등록 완료',
    );
  }

  Future<void> _importOne(AdminOpsController c, String url) async {
    await _importUrls(c, [url], successMessage: '공고 1건 등록 완료');
  }

  void _toggleAll(bool select) {
    setState(() {
      _selectedUrls.clear();
      if (select) {
        _selectedUrls.addAll(
          _previewRows
              .where((r) => r.ok && !_importedUrls.contains(r.url))
              .map((r) => r.url),
        );
      }
    });
  }

  List<Map<String, dynamic>> _parseJobsJson() {
    final decoded = jsonDecode(_jsonCtrl.text);
    if (decoded is! List) {
      throw FormatException('JSON 배열이어야 합니다');
    }
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final selectableCount = _previewRows
        .where((r) => r.ok && !_importedUrls.contains(r.url))
        .length;
    final selectedPending =
        _selectedUrls.where((u) => !_importedUrls.contains(u)).length;

    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminEventPinsCard(controller: c),
          const SizedBox(height: 16),
          AdminCard(
            title: '알바몬 링크 가져오기',
            subtitle:
                '1) 검색/상세 URL 붙여넣기 → 불러오기  2) 체크 또는 개별 등록. '
                '불러오기만으로는 DB에 올라가지 않습니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(
                  label: '알바몬 URL (검색 URL 1개 또는 상세 URL 여러 줄, 최대 30건)',
                  controller: _urlTextCtrl,
                  maxLines: 8,
                  hint:
                      'https://www.albamon.com/total-search?keyword=통근버스',
                ),
                Text(
                  '입력 링크: ${_countUrls(_urlTextCtrl.text)}개',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminField(
                        label: '사업자번호(company_key)',
                        controller: _companyKeyCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminField(
                        label: '회사명',
                        controller: _companyNameCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AdminField(
                        label: '등록자 이메일 (선택)',
                        controller: _postedByEmailCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AdminField(
                        label: '등록자 이름 (선택)',
                        controller: _postedByNameCtrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('등록 시 일자리핀 자동 ON (지도 노출)'),
                  value: _activateJobPin,
                  onChanged: c.busy
                      ? null
                      : (value) => setState(() => _activateJobPin = value),
                ),
                FilledButton.tonalIcon(
                  onPressed: !c.apiReady ||
                          c.busy ||
                          _previewing ||
                          _countUrls(_urlTextCtrl.text) == 0
                      ? null
                      : () => _previewUrls(c),
                  icon: _previewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    _previewing ? '불러오는 중…' : '공고 목록 불러오기 (미리보기)',
                  ),
                ),
                if (_previewRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '불러온 공고 ${_previewRows.length}건',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: selectableCount == 0
                            ? null
                            : () => _toggleAll(
                                  selectedPending < selectableCount,
                                ),
                        child: Text(
                          selectedPending == selectableCount &&
                                  selectableCount > 0
                              ? '전체 해제'
                              : '전체 선택',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._previewRows.map((row) {
                    final imported = _importedUrls.contains(row.url);
                    final selected = _selectedUrls.contains(row.url);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: imported ? false : selected,
                              onChanged: !row.ok || imported || c.busy
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedUrls.add(row.url);
                                        } else {
                                          _selectedUrls.remove(row.url);
                                        }
                                      });
                                    },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: row.ok
                                          ? null
                                          : Theme.of(context)
                                              .colorScheme
                                              .error,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    row.url,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (row.workplace.isNotEmpty ||
                                      row.hourlyWage.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          if (row.workplace.isNotEmpty)
                                            row.workplace,
                                          if (row.hourlyWage.isNotEmpty)
                                            row.hourlyWage,
                                        ].join(' · '),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  if (row.error != null)
                                    Text(
                                      row.error!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  if (imported)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        '등록 완료',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: !row.ok ||
                                      imported ||
                                      c.busy ||
                                      !c.apiReady
                                  ? null
                                  : () => _importOne(c, row.url),
                              child: Text(imported ? '완료' : '등록'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: !c.apiReady || c.busy || selectedPending == 0
                        ? null
                        : () => _importSelected(c),
                    icon: const Icon(Icons.upload_rounded),
                    label: Text('선택 $selectedPending건 등록'),
                  ),
                ],
                if (_lastUrlImportResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '최근 등록 결과',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._lastUrlImportResults.take(20).map((row) {
                    final ok = row['ok'] == true;
                    final title = row['title']?.toString() ?? '';
                    final postId = row['post_id']?.toString() ?? '';
                    final error = row['error']?.toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ok
                            ? '✓ $title ($postId)'
                            : '✗ ${row['url']} — ${error ?? '실패'}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              ok ? null : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: !c.apiReady || c.busy
                      ? null
                      : () => c.run(
                            () => c.client.remirrorJobDescriptionImages(
                              limit: 50,
                            ),
                            successMessage:
                                '본문 이미지 재정비 완료 (알바몬 BFF 재수집 · 로고 오탐 제거)',
                          ),
                  icon: const Icon(Icons.image_search_rounded),
                  label: const Text('이미지 본문 재정비 (로고 제거·BFF 재수집)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            title: '공고 bulk import',
            subtitle: '거래처 공고 JSON 붙여넣기 → 서버 DB 등록',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(
                  label: '공고 JSON 배열',
                  controller: _jsonCtrl,
                  maxLines: 14,
                ),
                Row(
                  children: [
                    FilledButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.bulkImportJobs(_parseJobsJson()),
                                successMessage: '공고 import 완료',
                              ),
                      child: const Text('공고 업로드'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _loadExampleJson,
                      child: const Text('예시 불러오기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdminCard(
            title: '일자리핀 · 정류장 노출',
            subtitle: '공고 ID 기준 entitlement ON',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(label: '공고 ID', controller: _postIdCtrl),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.setJobPin(
                                  postId: _postIdCtrl.text.trim(),
                                  active: true,
                                  mapPinTier: 'packageActive',
                                ),
                                successMessage: '일자리핀 ON',
                              ),
                      child: const Text('일자리핀 ON'),
                    ),
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.setJobPin(
                                  postId: _postIdCtrl.text.trim(),
                                  active: false,
                                ),
                                successMessage: '일자리핀 OFF',
                              ),
                      child: const Text('일자리핀 OFF'),
                    ),
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.setShuttleExposure(
                                  postId: _postIdCtrl.text.trim(),
                                  active: true,
                                ),
                                successMessage: '정류장 노출 ON',
                              ),
                      child: const Text('정류장 노출 ON'),
                    ),
                    OutlinedButton(
                      onPressed: !c.apiReady || c.busy
                          ? null
                          : () => c.run(
                                () => c.client.setShuttleExposure(
                                  postId: _postIdCtrl.text.trim(),
                                  active: false,
                                ),
                                successMessage: '정류장 노출 OFF',
                              ),
                      child: const Text('정류장 OFF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewJobRow {
  const _PreviewJobRow({
    required this.url,
    required this.title,
    required this.workplace,
    required this.hourlyWage,
    required this.ok,
    this.error,
  });

  final String url;
  final String title;
  final String workplace;
  final String hourlyWage;
  final bool ok;
  final String? error;

  factory _PreviewJobRow.fromJson(Map<String, dynamic> json) {
    return _PreviewJobRow(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '제목 확인 필요',
      workplace: json['workplace']?.toString() ?? '',
      hourlyWage: json['hourly_wage']?.toString() ?? '',
      ok: json['ok'] == true,
      error: json['error']?.toString(),
    );
  }
}

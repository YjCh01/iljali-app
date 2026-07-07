import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
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
  List<Map<String, dynamic>> _lastUrlImportResults = const [];

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

  Future<void> _bulkImportUrls(AdminOpsController c) async {
    final result = await c.run(
      () => c.client.bulkImportJobUrls(
        urlText: _urlTextCtrl.text,
        companyKey: _companyKeyCtrl.text.trim(),
        companyName: _companyNameCtrl.text.trim(),
        postedByEmail: _postedByEmailCtrl.text.trim(),
        postedByName: _postedByNameCtrl.text.trim(),
        activateJobPin: _activateJobPin,
      ),
      successMessage: '알바몬 링크 일괄 등록 완료',
    );
    final raw = result['results'];
    if (!mounted || raw is! List) return;
    setState(() {
      _lastUrlImportResults =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return AdminPanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminCard(
            title: '알바몬 링크 일괄 가져오기',
            subtitle:
                '링크를 줄마다 붙여넣기 → 확인 시 아라컴퍼니 공고로 바로 등록 (빈 항목은 나중에 수정)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminField(
                  label: '알바몬 URL (한 줄에 하나, 최대 30개)',
                  controller: _urlTextCtrl,
                  maxLines: 10,
                  hint:
                      'https://www.albamon.com/job/...\nhttps://www.albamon.com/job/...',
                ),
                Text(
                  '감지된 링크: ${_countUrls(_urlTextCtrl.text)}개',
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
                  title: const Text('일자리핀 자동 ON (지도 노출)'),
                  value: _activateJobPin,
                  onChanged: c.busy
                      ? null
                      : (value) => setState(() => _activateJobPin = value),
                ),
                FilledButton.icon(
                  onPressed: !c.apiReady ||
                          c.busy ||
                          _countUrls(_urlTextCtrl.text) == 0
                      ? null
                      : () => _bulkImportUrls(c),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('확인 · 일괄 등록'),
                ),
                if (_lastUrlImportResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '최근 등록 결과',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._lastUrlImportResults.map((row) {
                    final ok = row['ok'] == true;
                    final title = row['title']?.toString() ?? '';
                    final postId = row['post_id']?.toString() ?? '';
                    final error = row['error']?.toString();
                    final imageCount = row['image_count'];
                    final imageLabel = imageCount is num && imageCount > 0
                        ? ' · 이미지 ${imageCount.toInt()}장'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ok
                            ? '✓ $title ($postId)$imageLabel'
                            : '✗ ${row['url']} — ${error ?? '실패'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ok ? null : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }),
                ],
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

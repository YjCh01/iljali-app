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

  @override
  void initState() {
    super.initState();
    _loadExampleJson();
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
    super.dispose();
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

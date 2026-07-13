import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/admin/admin_api_errors.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';
import 'package:share_plus/share_plus.dart';

class AdminShuttleRouteImportCard extends StatefulWidget {
  const AdminShuttleRouteImportCard({
    super.key,
    required this.controller,
    required this.companyKey,
    this.companyName,
  });

  final AdminOpsController controller;
  final String companyKey;
  final String? companyName;

  @override
  State<AdminShuttleRouteImportCard> createState() =>
      _AdminShuttleRouteImportCardState();
}

class _AdminShuttleRouteImportCardState extends State<AdminShuttleRouteImportCard> {
  static const _templateAsset =
      'assets/templates/shuttle_route_import_template.xlsx';

  String? _selectedFileName;
  List<int>? _selectedBytes;
  Map<String, dynamic>? _lastResult;
  String? _error;
  bool _replaceExisting = true;

  Future<void> _downloadTemplate() async {
    try {
      final data = await rootBundle.load(_templateAsset);
      final bytes = data.buffer.asUint8List();
      const fileName = '셔틀노선_입력양식.xlsx';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: '셔틀 노선 입력 양식',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 양식을 내려받았습니다.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('양식 다운로드 실패: $error')),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = '파일을 읽을 수 없습니다.');
      return;
    }
    setState(() {
      _selectedFileName = file.name;
      _selectedBytes = bytes;
      _error = null;
      _lastResult = null;
    });
  }

  Future<void> _upload() async {
    final bytes = _selectedBytes;
    final fileName = _selectedFileName;
    if (bytes == null || fileName == null) {
      setState(() => _error = '업로드할 엑셀 파일을 선택해 주세요.');
      return;
    }

    setState(() {
      _error = null;
      _lastResult = null;
    });

    try {
      final result = await widget.controller.run(
        () => widget.controller.client.bulkImportShuttleRoutes(
          companyKey: widget.companyKey,
          fileBytes: bytes,
          fileName: fileName,
          replaceExisting: _replaceExisting,
        ),
        successMessage: '셔틀 노선 엑셀 등록 완료',
      );
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '노선 ${result['submitted_routes'] ?? 0}개 등록 '
            '(신규 ${result['imported'] ?? 0} · 갱신 ${result['updated'] ?? 0})',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = AdminApiErrors.format(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final subtitle = widget.companyName ?? widget.companyKey;

    return AdminCard(
      title: '셔틀 노선 엑셀 일괄 등록',
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '기업회원에게 엑셀 양식을 전달해 노선명·정류장·시간을 입력받은 뒤, '
            '받은 파일을 업로드하면 노선이 한 번에 등록됩니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('엑셀 양식 받기'),
              ),
              OutlinedButton.icon(
                onPressed: !c.apiReady || c.busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('엑셀 파일 선택'),
              ),
              FilledButton.icon(
                onPressed: !c.apiReady || c.busy || _selectedBytes == null
                    ? null
                    : _upload,
                icon: const Icon(Icons.directions_bus_outlined, size: 18),
                label: const Text('노선 일괄 등록'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('같은 노선명이 있으면 덮어쓰기'),
            subtitle: const Text(
              '끄면 항상 새 노선으로 추가됩니다.',
              style: TextStyle(fontSize: 12),
            ),
            value: _replaceExisting,
            onChanged: c.busy
                ? null
                : (value) => setState(() => _replaceExisting = value),
          ),
          if (_selectedFileName != null) ...[
            const SizedBox(height: 4),
            Text(
              '선택 파일: $_selectedFileName',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            _ImportSummary(result: _lastResult!),
          ],
          const SizedBox(height: 8),
          Text(
            '양식: 노선입력 시트 · 노선명·정류장순서·정류장명·도착시간·주소(선택)',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final rows = result['results'] as List<dynamic>? ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '등록 ${result['submitted_routes'] ?? 0}노선 · '
            '신규 ${result['imported'] ?? 0} · 갱신 ${result['updated'] ?? 0}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          for (final item in rows)
            if (item is Map)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '· ${item['route_name']} — ${item['stop_count']}정류장 '
                  '(${item['action'] == 'updated' ? '갱신' : '신규'})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
        ],
      ),
    );
  }
}

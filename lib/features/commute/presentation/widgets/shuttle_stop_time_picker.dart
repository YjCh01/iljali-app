import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map/core/constants/app_colors.dart';

/// 정류장 탑승·도착 시각 — HH:MM 팝업
Future<String?> showShuttleStopTimePickerDialog(
  BuildContext context, {
  String? initialTime,
  required String title,
  String? subtitle,
  bool required = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ShuttleStopTimePickerDialog(
      initialTime: initialTime,
      title: title,
      subtitle: subtitle,
      required: required,
    ),
  );
}

class _ShuttleStopTimePickerDialog extends StatefulWidget {
  const _ShuttleStopTimePickerDialog({
    this.initialTime,
    required this.title,
    this.subtitle,
    required this.required,
  });

  final String? initialTime;
  final String title;
  final String? subtitle;
  final bool required;

  @override
  State<_ShuttleStopTimePickerDialog> createState() =>
      _ShuttleStopTimePickerDialogState();
}

class _ShuttleStopTimePickerDialogState
    extends State<_ShuttleStopTimePickerDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTime?.trim() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValidHhMm(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  String _normalize(String raw) {
    final parts = raw.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _openSystemPicker() async {
    final now = TimeOfDay.now();
    final initial = _parseTimeOfDay(_controller.text) ?? now;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: widget.title,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _error = null;
    });
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    if (!_isValidHhMm(raw.trim())) return null;
    final parts = raw.trim().split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _confirm() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      if (widget.required) {
        setState(() => _error = '시각을 입력해 주세요.');
        return;
      }
      Navigator.of(context).pop('');
      return;
    }
    if (!_isValidHhMm(raw)) {
      setState(() => _error = 'HH:MM 형식으로 입력해 주세요. (예: 07:30)');
      return;
    }
    Navigator.of(context).pop(_normalize(raw));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subtitle != null) ...[
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                hintText: '00:00',
                prefixIcon: IconButton(
                  tooltip: '시간 선택',
                  onPressed: _openSystemPicker,
                  icon: const Icon(Icons.schedule_outlined),
                ),
                errorText: _error,
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('확인'),
        ),
      ],
    );
  }
}

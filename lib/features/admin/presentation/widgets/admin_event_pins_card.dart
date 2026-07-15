import 'package:flutter/material.dart';
import 'package:map/features/admin/domain/admin_ops_controller.dart';
import 'package:map/features/admin/presentation/widgets/admin_web_scaffold.dart';
import 'package:map/features/job_seeker/data/datasources/event_map_pin_local_data_source.dart';
import 'package:map/features/job_seeker/domain/entities/event_map_pin.dart';

/// 어드민 — 이벤트핑 CRUD (색·좌표·퀴즈/투표 내용)
class AdminEventPinsCard extends StatefulWidget {
  const AdminEventPinsCard({super.key, required this.controller});

  final AdminOpsController controller;

  @override
  State<AdminEventPinsCard> createState() => _AdminEventPinsCardState();
}

class _AdminEventPinsCardState extends State<AdminEventPinsCard> {
  final _titleCtrl = TextEditingController(text: '근처 출근 퀴즈');
  final _bodyCtrl = TextEditingController(
    text: '근로와 업무에 관한 짧은 퀴즈입니다. 눌러서 맞춰보세요!',
  );
  final _latCtrl = TextEditingController(text: '37.5665');
  final _lngCtrl = TextEditingController(text: '126.9780');
  final _colorCtrl = TextEditingController(text: '#FF6F00');
  final _optionsCtrl = TextEditingController(
    text: '주휴수당\n야식비\n교통비',
  );
  EventPinKind _kind = EventPinKind.quiz;
  int _correctIndex = 0;
  List<EventMapPin> _pins = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _colorCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final c = widget.controller;
    try {
      final raw = await c.client.listEventPins();
      if (!mounted) return;
      final mapped = raw
          .map((e) => EventMapPin.fromJson(e))
          .where((p) => p.id.isNotEmpty)
          .toList();
      EventMapPinLocalDataSourceImpl.replaceFromServer(mapped);
      setState(() => _pins = mapped);
    } on Object {
      // keep previous list
    }
  }

  List<String> _parseOptions() => _optionsCtrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(8)
      .toList();

  Future<void> _create() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위도·경도를 숫자로 입력해 주세요.')),
      );
      return;
    }
    final options = _parseOptions();
    final payload = <String, dynamic>{
      'options': options,
      if (_kind == EventPinKind.quiz && options.isNotEmpty)
        'correct_index': _correctIndex.clamp(0, options.length - 1),
    };
    final c = widget.controller;
    await c.run(
      () => c.client.createEventPin(
        latitude: lat,
        longitude: lng,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        kind: _kind.name,
        colorHex: _colorCtrl.text.trim(),
        payload: payload,
      ),
      successMessage: '이벤트핑 등록 완료',
    );
    await _reload();
  }

  Future<void> _delete(String id) async {
    final c = widget.controller;
    await c.run(
      () => c.client.deleteEventPin(id),
      successMessage: '이벤트핑 삭제',
    );
    EventMapPinLocalDataSourceImpl.removeLocal(id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final options = _parseOptions();
    return AdminCard(
      title: '이벤트핑 (재미·퀴즈·투표)',
      subtitle:
          '공고가 적을 때 지도에 띄워 구직자를 붙잡는 핀. 색·위치·그리드 내용을 간단히 등록합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '본문 (그리드 안내)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<EventPinKind>(
                  value: _kind,
                  decoration: const InputDecoration(
                    labelText: '유형',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final kind in EventPinKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _kind = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _colorCtrl,
                  decoration: const InputDecoration(
                    labelText: '핀 색 (#HEX)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  decoration: const InputDecoration(
                    labelText: '위도',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  decoration: const InputDecoration(
                    labelText: '경도',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          if (_kind != EventPinKind.info) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _optionsCtrl,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '선택지 (한 줄에 하나)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_kind == EventPinKind.quiz && options.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _correctIndex.clamp(0, options.length - 1),
                decoration: const InputDecoration(
                  labelText: '정답',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (var i = 0; i < options.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('${i + 1}. ${options[i]}'),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _correctIndex = v);
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.busy ? null : _create,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('이벤트핑 등록'),
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 이벤트핑 ${_pins.length}개',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_pins.isEmpty)
            Text(
              '아직 없습니다. 지도에서 볼거리를 늘리려면 하나 등록해 보세요.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            )
          else
            for (final pin in _pins)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  pin.title.isEmpty ? '(제목 없음)' : pin.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${pin.kind.label} · ${pin.latitude.toStringAsFixed(4)}, '
                  '${pin.longitude.toStringAsFixed(4)}',
                ),
                trailing: IconButton(
                  tooltip: '삭제',
                  onPressed: widget.controller.busy
                      ? null
                      : () => _delete(pin.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
        ],
      ),
    );
  }
}

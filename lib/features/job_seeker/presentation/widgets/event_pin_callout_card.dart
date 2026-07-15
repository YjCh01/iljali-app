import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/event_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 이벤트핑 탭 시 — 안내 / 퀴즈 / 투표
class EventPinCalloutCard extends StatefulWidget {
  const EventPinCalloutCard({
    super.key,
    required this.pin,
    required this.onClose,
  });

  final JobMapPin pin;
  final VoidCallback onClose;

  @override
  State<EventPinCalloutCard> createState() => _EventPinCalloutCardState();
}

class _EventPinCalloutCardState extends State<EventPinCalloutCard> {
  int? _selectedIndex;
  String? _feedback;

  EventMapPin? get _event => widget.pin.eventPin;

  void _onOption(int index) {
    final event = _event;
    if (event == null) return;
    setState(() {
      _selectedIndex = index;
      switch (event.kind) {
        case EventPinKind.quiz:
          final correct = event.correctIndex;
          if (correct == null) {
            _feedback = '선택 완료!';
          } else if (index == correct) {
            _feedback = '정답입니다!';
          } else {
            _feedback = '아쉽네요. 다시 생각해 보세요.';
          }
        case EventPinKind.vote:
          _feedback = '투표가 반영되었습니다. 참여해 주셔서 감사합니다!';
        case EventPinKind.info:
          _feedback = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final title = event?.title.isNotEmpty == true
        ? event!.title
        : widget.pin.companyName;
    final body = event?.body ?? '';
    final options = event?.options ?? const <String>[];
    final kind = event?.kind ?? EventPinKind.info;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0B2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF6F00)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '★',
                    style: TextStyle(fontSize: 18, color: Color(0xFFE65100)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: widget.onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ],
            if (options.isNotEmpty &&
                (kind == EventPinKind.quiz || kind == EventPinKind.vote)) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _onOption(i),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _selectedIndex == i
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    side: BorderSide(
                      color: _selectedIndex == i
                          ? AppColors.primary
                          : AppColors.searchBarBorder,
                      width: _selectedIndex == i ? 1.6 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    options[i],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

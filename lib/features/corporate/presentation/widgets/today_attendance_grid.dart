import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';

/// 오늘 출근자 — 간략 그리드 (이름 · 성별 · 생년월일 · 출근/결근)
class TodayAttendanceGrid extends StatelessWidget {
  const TodayAttendanceGrid({
    super.key,
    required this.records,
    required this.onTapRecord,
  });

  final List<CorporateAttendanceRecord> records;
  final ValueChanged<CorporateAttendanceRecord> onTapRecord;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              '오늘 출근 예정자가 없습니다',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '근무예정 합의된 건 중\n오늘 근무일인 지원자가 여기 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _GridHeaderRow(
          dateLabel: _todayLabel(),
          count: records.length,
        ),
        const SizedBox(height: 8),
        ...records.map(
          (record) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _GridDataRow(
              record: record,
              onTap: () => onTapRecord(record),
            ),
          ),
        ),
      ],
    );
  }

  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }
}

class _GridHeaderRow extends StatelessWidget {
  const _GridHeaderRow({
    required this.dateLabel,
    required this.count,
  });

  final String dateLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$count명',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(flex: 26, child: _HeaderCell('이름')),
              Expanded(flex: 14, child: _HeaderCell('성별')),
              Expanded(flex: 24, child: _HeaderCell('생년월일')),
              Expanded(flex: 16, child: _HeaderCell('출근', align: TextAlign.center)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }
}

class _GridDataRow extends StatelessWidget {
  const _GridDataRow({
    required this.record,
    required this.onTap,
  });

  final CorporateAttendanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 26,
                child: Text(
                  record.workerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  record.genderLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 24,
                child: Text(
                  record.birthDateLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Expanded(
                flex: 16,
                child: Align(
                  alignment: Alignment.center,
                  child: _RollCallBadge(status: record.rollCallStatus),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollCallBadge extends StatelessWidget {
  const _RollCallBadge({required this.status});

  final TodayRollCallStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      TodayRollCallStatus.present => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
        ),
      TodayRollCallStatus.absent => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
        ),
      TodayRollCallStatus.pending => (
          AppColors.background,
          AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

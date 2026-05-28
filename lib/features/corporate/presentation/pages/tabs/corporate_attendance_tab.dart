import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/attendance_escalation_service.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/data/datasources/corporate_attendance_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_attendance_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_attendance_card.dart';
import 'package:map/features/hiring/presentation/widgets/commission_payment_dialog.dart';

/// 기업회원 4번 탭 — 근태 관리 · 수수료 결제
class CorporateAttendanceTab extends StatefulWidget {
  const CorporateAttendanceTab({super.key, this.isActive = false});

  /// IndexedStack 에서 비활성 탭일 때는 로드·수수료 다이얼로그를 띄우지 않음
  final bool isActive;

  @override
  State<CorporateAttendanceTab> createState() => _CorporateAttendanceTabState();
}

class _CorporateAttendanceTabState extends State<CorporateAttendanceTab> {
  final _getAttendance = const GetCorporateAttendanceUseCase(
    CorporateAttendanceLocalDataSourceImpl(),
  );

  List<CorporateAttendanceRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant CorporateAttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
      return;
    }
    if (widget.isActive && HiringRefresh.consumeIfDirty()) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AttendanceEscalationService.runEscalationPass(context);
    final records = await _getAttendance();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
    await _promptPendingCommissions();
  }

  Future<void> _promptPendingCommissions() async {
    final repo = await LocalHiringRepository.create();
    final pending = await repo.fetchPendingCommissions();
    if (!mounted) return;
    for (final app in pending) {
      final paid = await showCommissionPaymentDialog(context, app);
      if (paid == true) break;
    }
    if (pending.isNotEmpty && mounted) await _load();
  }

  Future<void> _openRecord(CorporateAttendanceRecord record) async {
    if (!record.needsCommissionPayment || record.applicationId == null) return;
    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(record.applicationId!);
    if (app == null || !mounted) return;
    final paid = await showCommissionPaymentDialog(context, app);
    if (paid == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: _records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = _records[index];
            return CorporateAttendanceCard(
              record: record,
              onTap: record.needsCommissionPayment
                  ? () => _openRecord(record)
                  : null,
            );
          },
        ),
      ),
    );
  }
}

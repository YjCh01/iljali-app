import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';

abstract class CorporateAttendanceLocalDataSource {
  Future<List<CorporateAttendanceRecord>> fetchRecords();
}

class CorporateAttendanceLocalDataSourceImpl
    implements CorporateAttendanceLocalDataSource {
  const CorporateAttendanceLocalDataSourceImpl();

  @override
  Future<List<CorporateAttendanceRecord>> fetchRecords() async {
    final repo = await LocalHiringRepository.create();
    final all = await repo.fetchAll();
    final records = all
        .where((item) =>
            item.status == HiringApplicationStatus.checkedIn ||
            item.status == HiringApplicationStatus.commissionPaid)
        .map(_mapRecord)
        .toList();
    return records;
  }

  CorporateAttendanceRecord _mapRecord(HiringApplication app) {
    final checkIn = app.checkedInAt;
    final checkInLabel = checkIn != null
        ? '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}'
        : '-';

    return CorporateAttendanceRecord(
      id: app.id,
      applicationId: app.id,
      workerName: app.seekerName,
      jobTitle: app.postTitle,
      workDateLabel: app.workDate != null
          ? LocalHiringRepository.formatWorkDateFull(app.workDate!)
          : '-',
      checkInLabel: checkInLabel,
      checkOutLabel: '-',
      status: _mapStatus(app),
      commissionAmountKrw: app.commissionAmountKrw,
      commissionPaid: app.status == HiringApplicationStatus.commissionPaid,
      escalationLevel: app.escalationLevel,
    );
  }

  CorporateAttendanceStatus _mapStatus(HiringApplication app) {
    if (app.status == HiringApplicationStatus.commissionPaid) {
      return CorporateAttendanceStatus.onTime;
    }
    if (app.needsCommissionPayment) {
      return CorporateAttendanceStatus.pendingCommission;
    }
    return CorporateAttendanceStatus.onTime;
  }
}

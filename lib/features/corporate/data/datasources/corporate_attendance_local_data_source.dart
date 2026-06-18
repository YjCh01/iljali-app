import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/work_schedule_time.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_attendance_record.dart';
import 'package:map/features/corporate/domain/services/seeker_profile_lookup.dart';

abstract class CorporateAttendanceLocalDataSource {
  Future<List<CorporateAttendanceRecord>> fetchRecords();
}

class CorporateAttendanceLocalDataSourceImpl
    implements CorporateAttendanceLocalDataSource {
  const CorporateAttendanceLocalDataSourceImpl();

  @override
  Future<List<CorporateAttendanceRecord>> fetchRecords() async {
    final repo = await LocalHiringRepository.create();
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    final all = await repo.fetchAll();
    final records = all
        .where((item) {
          if (companyKey != null &&
              companyKey.isNotEmpty &&
              item.companyKey != null &&
              item.companyKey != companyKey) {
            return false;
          }
          if (!item.isWorkAgreementComplete) return false;
          return item.status == HiringApplicationStatus.scheduled ||
              item.status == HiringApplicationStatus.checkedIn ||
              item.status == HiringApplicationStatus.commissionPaid ||
              item.status == HiringApplicationStatus.noShow;
        })
        .map(_mapRecord)
        .toList();
    return records;
  }

  CorporateAttendanceRecord _mapRecord(HiringApplication app) {
    final checkIn = app.checkedInAt;
    final checkInLabel = checkIn != null
        ? '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}'
        : '-';

    final awaitingEmployer = app.awaitingEmployerConfirm;
    final awaitingSeeker = app.awaitingSeekerCheckIn;
    final canEmployerConfirm = app.status == HiringApplicationStatus.scheduled &&
        !app.employerConfirmed &&
        !app.isMutuallyConfirmed;

    final canMarkNoShow = _canEmployerMarkNoShow(app);
    final seekerProfile = SeekerProfileLookup.forEmail(app.seekerEmail);
    final workAgreedAt = _latestWorkAgreedAt(app);

    return CorporateAttendanceRecord(
      id: app.id,
      applicationId: app.id,
      seekerEmail: app.seekerEmail,
      employmentType: app.employmentType,
      workerName: app.seekerName,
      genderLabel: seekerProfile.genderLabel,
      birthDateLabel: seekerProfile.birthDateLabel,
      jobTitle: app.postTitle,
      workDate: app.workDate,
      workDateLabel: app.workDate != null
          ? LocalHiringRepository.formatWorkDateFull(app.workDate!)
          : '-',
      appliedAt: app.appliedAt,
      workAgreedAt: workAgreedAt,
      phoneMasked: app.seekerPhoneMasked,
      checkInLabel: checkInLabel,
      checkOutLabel: '-',
      status: _mapStatus(app),
      commissionAmountKrw: app.commissionAmountKrw,
      commissionPaid: app.status == HiringApplicationStatus.commissionPaid,
      escalationLevel: app.escalationLevel,
      awaitingEmployerConfirm: awaitingEmployer,
      awaitingSeekerCheckIn: awaitingSeeker,
      canEmployerConfirm: canEmployerConfirm,
      workAgreementComplete: app.isWorkAgreementComplete,
      countdownLabel: WorkScheduleTime.countdownLabel(
        workDate: app.workDate,
        workSchedule: app.workSchedule,
      ),
      canMarkNoShow: canMarkNoShow,
      rollCallStatus: _rollCallStatus(app),
    );
  }

  static DateTime? _latestWorkAgreedAt(HiringApplication app) {
    final seeker = app.seekerWorkAgreedAt;
    final employer = app.employerWorkAgreedAt;
    if (seeker == null && employer == null) return null;
    if (seeker == null) return employer;
    if (employer == null) return seeker;
    return seeker.isAfter(employer) ? seeker : employer;
  }

  TodayRollCallStatus _rollCallStatus(HiringApplication app) {
    if (app.status == HiringApplicationStatus.noShow) {
      return TodayRollCallStatus.absent;
    }
    if (app.seekerCheckedIn ||
        app.isMutuallyConfirmed ||
        app.status == HiringApplicationStatus.commissionPaid) {
      return TodayRollCallStatus.present;
    }
    return TodayRollCallStatus.pending;
  }

  bool _canEmployerMarkNoShow(HiringApplication app) {
    if (app.status != HiringApplicationStatus.scheduled) return false;
    if (!app.isWorkAgreementComplete) return false;
    if (app.isMutuallyConfirmed) return false;
    final workDate = app.workDate;
    if (workDate != null) {
      final start = WorkScheduleTime.workStartAt(workDate, app.workSchedule);
      if (start != null && DateTime.now().isBefore(start)) return false;
    }
    return true;
  }

  CorporateAttendanceStatus _mapStatus(HiringApplication app) {
    if (app.status == HiringApplicationStatus.noShow) {
      return CorporateAttendanceStatus.absent;
    }
    if (app.status == HiringApplicationStatus.commissionPaid) {
      return CorporateAttendanceStatus.onTime;
    }
    if (!ProductFeatureFlags.isHiringCommissionEnabled &&
        app.isMutuallyConfirmed) {
      return CorporateAttendanceStatus.onTime;
    }
    if (app.awaitingEmployerConfirm) {
      return CorporateAttendanceStatus.awaitingEmployerConfirm;
    }
    if (app.awaitingSeekerCheckIn) {
      return CorporateAttendanceStatus.awaitingSeekerCheckIn;
    }
    if (app.needsCommissionPayment) {
      return CorporateAttendanceStatus.pendingCommission;
    }
    if (app.isMutuallyConfirmed) {
      return CorporateAttendanceStatus.onTime;
    }
    return CorporateAttendanceStatus.onTime;
  }
}

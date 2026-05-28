import 'package:map/core/constants/labor_constants.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';

import 'package:map/features/corporate/domain/entities/worker_category.dart';



/// 일자리 작성 폼 초기값

class JobPostWriteDraft {

  const JobPostWriteDraft({

    this.title = '',

    this.workplaceAddress,

    this.jobDescription = '',

    this.hourlyWage = LaborConstants.defaultHourlyWageText,

    this.workSchedule = '',

    this.summary = '',

    this.employmentType = JobEmploymentType.daily,

    this.workerCategory = WorkerCategory.general,

    this.paymentDate,

    this.paymentMonthOffset,

    this.paymentDayOfMonth,

    this.notificationSettings,

  });



  final String title;

  final String? workplaceAddress;

  final String jobDescription;

  final String hourlyWage;

  final String workSchedule;

  final String summary;

  final JobEmploymentType employmentType;

  final WorkerCategory workerCategory;

  final DateTime? paymentDate;

  final SalaryPaymentMonthOffset? paymentMonthOffset;

  final int? paymentDayOfMonth;

  final JobPostNotificationSettings? notificationSettings;



  JobPostWriteDraft copyWith({

    String? title,

    String? workplaceAddress,

    String? jobDescription,

    String? hourlyWage,

    String? workSchedule,

    String? summary,

    DateTime? paymentDate,

    SalaryPaymentMonthOffset? paymentMonthOffset,

    int? paymentDayOfMonth,

    JobPostNotificationSettings? notificationSettings,

    JobEmploymentType? employmentType,

    WorkerCategory? workerCategory,

  }) {

    return JobPostWriteDraft(

      title: title ?? this.title,

      workplaceAddress: workplaceAddress ?? this.workplaceAddress,

      jobDescription: jobDescription ?? this.jobDescription,

      hourlyWage: hourlyWage ?? this.hourlyWage,

      workSchedule: workSchedule ?? this.workSchedule,

      summary: summary ?? this.summary,

      employmentType: employmentType ?? this.employmentType,

      workerCategory: workerCategory ?? this.workerCategory,

      paymentDate: paymentDate ?? this.paymentDate,

      paymentMonthOffset: paymentMonthOffset ?? this.paymentMonthOffset,

      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,

      notificationSettings: notificationSettings ?? this.notificationSettings,

    );

  }

}


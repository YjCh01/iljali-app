import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';

import 'package:map/features/corporate/domain/entities/worker_category.dart';

import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';

import 'package:map/core/constants/labor_constants.dart';
import 'package:map/core/widgets/comma_number_input_formatter.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_service_action_style.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_description_body_editor.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_field_preview.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_selector_field.dart';
import 'package:map/features/work_category/presentation/widgets/work_category_picker_field.dart';



/// 일자리 등록·수정 공통 폼

class CorporateJobPostForm extends StatefulWidget {

  const CorporateJobPostForm({

    super.key,

    required this.titleController,

    required this.descriptionBody,

    required this.onDescriptionBodyChanged,

    required this.wageController,

    required this.scheduleController,

    required this.workplace,

    required this.onSearchWorkplace,

    this.onLoadRegisteredWorkplace,

    this.loadingRegisteredWorkplace = false,

    required this.workerCategory,

    required this.onWorkerCategoryChanged,

    this.workCategoryId,

    required this.onWorkCategoryChanged,

    required this.salaryPayType,

    required this.onSalaryPayTypeChanged,

    required this.paymentDate,

    required this.onPickPaymentDate,

    this.paymentMonthOffset,

    this.paymentDayOfMonth,

    required this.onPaymentMonthOffsetChanged,

    required this.onPaymentDayOfMonthChanged,

    required this.notificationSettings,

    required this.onConfigurePushNotification,

    required this.submitLabel,

    required this.submitting,

    required this.onSubmit,

    this.beforeSubmit,

    this.afterSubmit,

    this.showExposureSection = true,

    this.onDailyScheduleCommitted,

    this.paymentDateNegotiable = false,

    required this.onPaymentDateNegotiableChanged,

    this.workScheduleNegotiable = false,

    required this.onWorkScheduleNegotiableChanged,

  });



  final TextEditingController titleController;

  final JobPostDescriptionBody descriptionBody;

  final ValueChanged<JobPostDescriptionBody> onDescriptionBodyChanged;

  final TextEditingController wageController;

  final TextEditingController scheduleController;

  final WorkplaceAddress? workplace;

  final VoidCallback onSearchWorkplace;

  final Future<void> Function()? onLoadRegisteredWorkplace;

  final bool loadingRegisteredWorkplace;

  final WorkerCategory workerCategory;

  final ValueChanged<WorkerCategory> onWorkerCategoryChanged;

  final String? workCategoryId;

  final ValueChanged<String?> onWorkCategoryChanged;

  final SalaryPayType salaryPayType;

  final ValueChanged<SalaryPayType> onSalaryPayTypeChanged;

  final DateTime? paymentDate;

  final VoidCallback onPickPaymentDate;

  final SalaryPaymentMonthOffset? paymentMonthOffset;

  final int? paymentDayOfMonth;

  final ValueChanged<SalaryPaymentMonthOffset?> onPaymentMonthOffsetChanged;

  final ValueChanged<int?> onPaymentDayOfMonthChanged;

  final JobPostNotificationSettings? notificationSettings;

  final VoidCallback onConfigurePushNotification;

  final String submitLabel;

  final bool submitting;

  final VoidCallback onSubmit;

  final Widget? beforeSubmit;

  final Widget? afterSubmit;

  final bool showExposureSection;

  final VoidCallback? onDailyScheduleCommitted;

  final bool paymentDateNegotiable;

  final ValueChanged<bool> onPaymentDateNegotiableChanged;

  final bool workScheduleNegotiable;

  final ValueChanged<bool> onWorkScheduleNegotiableChanged;



  @override

  State<CorporateJobPostForm> createState() => _CorporateJobPostFormState();

}



class _CorporateJobPostFormState extends State<CorporateJobPostForm> {
  @override
  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        const FieldLabel('공고 제목'),

        TextField(

          controller: widget.titleController,

          textInputAction: TextInputAction.next,

          decoration: _inputDecoration('예: 당일배송 분류·포장'),

        ),

        const SizedBox(height: 16),

        const FieldLabel('근무지'),

        _WorkplaceField(

          workplace: widget.workplace,

          onTap: widget.onSearchWorkplace,

        ),

        if (widget.onLoadRegisteredWorkplace != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.loadingRegisteredWorkplace
                  ? null
                  : () => widget.onLoadRegisteredWorkplace!(),
              icon: widget.loadingRegisteredWorkplace
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.business_outlined, size: 18),
              label: Text(
                widget.loadingRegisteredWorkplace
                    ? '사업장 소재지 확인 중...'
                    : '등록증·사업자 소재지 불러오기',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '가입·내정보에 제출한 사업자등록증의 사업장 주소를 근무지에 채웁니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        const FieldLabel('업무 내용'),

        JobPostDescriptionBodyEditor(
          body: widget.descriptionBody,
          onChanged: widget.onDescriptionBodyChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '구직자 공고 상세 화면 본문에 표시됩니다.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),

        const SizedBox(height: 16),

        const FieldLabel('고용 형태'),

        SegmentedButton<WorkerCategory>(

          segments: ProductFeatureFlags.workerCategoriesForForm(
            current: widget.workerCategory,
          )
              .map(

                (category) => ButtonSegment(

                  value: category,

                  label: Text(category.label),

                ),

              )

              .toList(),

          selected: {widget.workerCategory},

          onSelectionChanged: (selection) =>

              widget.onWorkerCategoryChanged(selection.first),

          style: ButtonStyle(

            visualDensity: VisualDensity.compact,

            tapTargetSize: MaterialTapTargetSize.shrinkWrap,

          ),

        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        const SizedBox(height: 16),

        const FieldLabel('근무 일정'),

        WorkScheduleSelectorField(
          controller: widget.scheduleController,
          dailyOnly: widget.workerCategory.usesDailyPickSchedule,
          firstStartDateOnly: widget.workerCategory.usesFirstStartDateOnly,
          workScheduleNegotiable: widget.workScheduleNegotiable,
          onWorkScheduleNegotiableChanged: widget.onWorkScheduleNegotiableChanged,
          onDailyScheduleCommitted: widget.onDailyScheduleCommitted,
        ),

        const SizedBox(height: 16),

        const FieldLabel('급여 (단위: 원)'),

        Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Expanded(

              flex: 2,

              child: DropdownButtonFormField<SalaryPayType>(

                value: widget.salaryPayType,

                decoration: _inputDecoration('단위'),

                items: SalaryPayType.values

                    .map(

                      (type) => DropdownMenuItem(

                        value: type,

                        child: Text(type.label),

                      ),

                    )

                    .toList(),

                onChanged: (value) {
                  if (value == null || value == widget.salaryPayType) return;
                  if (value == SalaryPayType.hourly) {
                    widget.wageController.text =
                        LaborConstants.defaultHourlyWageFieldText;
                  } else {
                    widget.wageController.clear();
                  }
                  widget.onSalaryPayTypeChanged(value);
                },

              ),

            ),

            const SizedBox(width: 10),

            Expanded(

              flex: 3,

              child: TextField(

                controller: widget.wageController,

                keyboardType: TextInputType.number,

                inputFormatters: const [CommaNumberInputFormatter()],

                decoration: _inputDecoration(

                  '예: ${LaborConstants.defaultHourlyWageFieldText}',

                ),

              ),

            ),

          ],

        ),

        _PremiumWageMapHint(
          salaryPayType: widget.salaryPayType,
        ),

        const SizedBox(height: 16),

        const FieldLabel('급여지급일'),

        if (widget.workerCategory.usesAbsolutePaymentDate)

          ListenableBuilder(
            listenable: widget.scheduleController,
            builder: (context, _) => _DailyPaymentDatesField(
              workScheduleRaw: widget.scheduleController.text,
              negotiable: widget.paymentDateNegotiable,
              onNegotiableChanged: widget.onPaymentDateNegotiableChanged,
            ),
          )

        else if (widget.workerCategory.usesCalendarPaymentDate)

          _CalendarPaymentDateField(
            paymentDate: widget.paymentDate,
            negotiable: widget.paymentDateNegotiable,
            onPickDate: widget.onPickPaymentDate,
            onNegotiableChanged: widget.onPaymentDateNegotiableChanged,
          )

        else if (widget.workerCategory.usesMonthlyPaymentDate)

          _MonthlyPaymentDayField(

            monthOffset: widget.paymentMonthOffset,

            dayOfMonth: widget.paymentDayOfMonth,

            onMonthOffsetChanged: widget.onPaymentMonthOffsetChanged,

            onDayOfMonthChanged: widget.onPaymentDayOfMonthChanged,

          ),

        const SizedBox(height: 16),

        if (widget.showExposureSection) ...[
        const FieldLabel('공고 노출 범위'),

        Padding(

          padding: const EdgeInsets.only(bottom: 8),

          child: Text(

            PushPlanEnforcement.planLimitSummary(),

            style: TextStyle(

              fontSize: 12,

              fontWeight: FontWeight.w600,

              color: AppColors.textSecondary.withValues(alpha: 0.95),

            ),

          ),

        ),

        _PushNotificationField(

          settings: widget.notificationSettings,

          onTap: widget.onConfigurePushNotification,

        ),
        ],

        if (widget.beforeSubmit != null) ...[

          const SizedBox(height: 16),

          widget.beforeSubmit!,

        ],

        const SizedBox(height: 16),

        const FieldLabel('업무 카테고리'),

        WorkCategoryPickerField(
          selectedId: widget.workCategoryId,
          onChanged: widget.onWorkCategoryChanged,
          title: widget.titleController.text,
          jobDescription: widget.descriptionBody.legacyPlainText,
        ),

        const SizedBox(height: 28),

        FilledButton(

          onPressed: widget.submitting ? null : widget.onSubmit,

          style: FilledButton.styleFrom(

            backgroundColor: AppColors.primary,

            foregroundColor: Colors.white,

            padding: const EdgeInsets.symmetric(vertical: 16),

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(14),

            ),

          ),

          child: widget.submitting

              ? const SizedBox(

                  height: 20,

                  width: 20,

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                    color: Colors.white,

                  ),

                )

              : Text(

                  widget.submitLabel,

                  style: const TextStyle(fontWeight: FontWeight.w700),

                ),

        ),

          ],
        ),

        if (widget.afterSubmit != null) ...[

          const SizedBox(height: 16),

          const Text(
            '유료 서비스 (선택)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          widget.afterSubmit!,

        ],

      ],

    );

  }



  InputDecoration _inputDecoration(String hint) {

    return InputDecoration(

      hintText: hint,

      filled: true,

      fillColor: AppColors.surface,

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide(color: AppColors.searchBarBorder),

      ),

      enabledBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide(color: AppColors.searchBarBorder),

      ),

      focusedBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),

      ),

    );

  }

}



class _WorkplaceField extends StatelessWidget {

  const _WorkplaceField({

    required this.workplace,

    required this.onTap,

  });



  final WorkplaceAddress? workplace;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    final hasAddress = workplace != null;

    return Material(

      color: AppColors.surface,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Ink(

          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(14),

            border: Border.all(

              color: hasAddress

                  ? AppColors.primary.withValues(alpha: 0.4)

                  : AppColors.searchBarBorder,

            ),

          ),

          child: Row(

            children: [

              Icon(

                Icons.search_rounded,

                color: hasAddress

                    ? AppColors.primary

                    : AppColors.textSecondary.withValues(alpha: 0.8),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Text(

                  hasAddress

                      ? workplace!.displayLabel

                      : '동·도로명 검색',

                  style: TextStyle(

                    fontSize: 15,

                    fontWeight:

                        hasAddress ? FontWeight.w600 : FontWeight.w400,

                    color: hasAddress

                        ? AppColors.textPrimary

                        : AppColors.textSecondary.withValues(alpha: 0.9),

                  ),

                ),

              ),

              const Icon(Icons.chevron_right_rounded,

                  color: AppColors.textSecondary),

            ],

          ),

        ),

      ),

    );

  }

}



class _PremiumWageMapHint extends StatelessWidget {
  const _PremiumWageMapHint({
    required this.salaryPayType,
  });

  final SalaryPayType salaryPayType;

  @override
  Widget build(BuildContext context) {
    if (salaryPayType != SalaryPayType.hourly &&
        salaryPayType != SalaryPayType.daily) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.place_outlined,
            size: 14,
            color: Color(0xFF29B6F6),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              LaborConstants.premiumWageMapHint,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyPaymentDatesField extends StatelessWidget {
  const _DailyPaymentDatesField({
    required this.workScheduleRaw,
    required this.negotiable,
    required this.onNegotiableChanged,
  });

  final String workScheduleRaw;
  final bool negotiable;
  final ValueChanged<bool> onNegotiableChanged;

  @override
  Widget build(BuildContext context) {
    final paymentDates =
        DailyWorkerPolicy.paymentDatesFromWorkSchedule(workScheduleRaw);
    final chips =
        paymentDates.map(WorkSchedulePreviewFormatter.formatChipDate).toList();
    final hasDates = chips.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasDates || negotiable
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.searchBarBorder,
              ),
            ),
            child: negotiable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '급여지급일',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => onNegotiableChanged(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            '협의',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : hasDates
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '급여지급일 ${chips.length}일',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final chip in chips) _DateChip(label: chip),
                          OutlinedButton(
                            onPressed: () => onNegotiableChanged(true),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: AppColors.searchBarBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '협의',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '근무일 선택 후 자동 설정',
                          style: TextStyle(
                            fontSize: 15,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DailyWorkerPolicy.paymentAutoSetupLine1,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              Text(
                DailyWorkerPolicy.paymentAutoSetupLine2,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarPaymentDateField extends StatelessWidget {
  const _CalendarPaymentDateField({
    required this.paymentDate,
    required this.negotiable,
    required this.onPickDate,
    required this.onNegotiableChanged,
  });

  final DateTime? paymentDate;
  final bool negotiable;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onNegotiableChanged;

  @override
  Widget build(BuildContext context) {
    final dateLabel = paymentDate == null
        ? null
        : WorkSchedulePreviewFormatter.formatChipDate(paymentDate!);
    final hasDate = dateLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasDate || negotiable
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.searchBarBorder,
              ),
            ),
            child: negotiable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '급여지급일',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => onNegotiableChanged(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            '협의',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : hasDate
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '급여지급일',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: onPickDate,
                                borderRadius: BorderRadius.circular(8),
                                child: _DateChip(label: dateLabel),
                              ),
                              OutlinedButton(
                                onPressed: () => onNegotiableChanged(true),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(
                                    color: AppColors.searchBarBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  '협의',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: onPickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '급여 지급일 선택',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            '달력에서 급여 지급일을 선택하거나 협의로 표시할 수 있습니다.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PaymentDateField extends StatelessWidget {

  const _PaymentDateField({

    required this.paymentDate,

    required this.onTap,

    this.readOnly = false,

    this.helperText,

  });



  final DateTime? paymentDate;

  final VoidCallback onTap;

  final bool readOnly;

  final String? helperText;



  @override

  Widget build(BuildContext context) {

    final label = paymentDate == null
        ? (readOnly ? '근무일 선택 후 자동 설정' : '급여 지급일 선택')
        : '${paymentDate!.year}년 ${paymentDate!.month}월 ${paymentDate!.day}일';

    final field = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: readOnly ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: paymentDate != null
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.searchBarBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                readOnly ? Icons.event_available_outlined : Icons.calendar_month_outlined,
                color: paymentDate != null
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: paymentDate != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: paymentDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (!readOnly)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );

    if (helperText == null || helperText!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            helperText!,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}



class _MonthlyPaymentDayField extends StatelessWidget {

  const _MonthlyPaymentDayField({

    required this.monthOffset,

    required this.dayOfMonth,

    required this.onMonthOffsetChanged,

    required this.onDayOfMonthChanged,

  });



  final SalaryPaymentMonthOffset? monthOffset;

  final int? dayOfMonth;

  final ValueChanged<SalaryPaymentMonthOffset?> onMonthOffsetChanged;

  final ValueChanged<int?> onDayOfMonthChanged;



  bool get _isComplete => monthOffset != null && dayOfMonth != null;



  String get _label {

    if (!_isComplete) return '급여 지급일 선택';

    final schedule = SalaryPaymentSchedule.monthlyRule(

      monthOffset: monthOffset!,

      dayOfMonth: dayOfMonth!,

    );

    return schedule.displayLabel;

  }



  Future<void> _openPicker(BuildContext context) async {

    var selectedOffset = monthOffset ?? SalaryPaymentMonthOffset.sameMonth;

    var selectedDay = dayOfMonth ?? 25;



    final saved = await showAdaptiveSheet<bool>(

      context: context,

      builder: (sheetContext) {

        return StatefulBuilder(

          builder: (context, setSheetState) {

            return Padding(

              padding: EdgeInsets.fromLTRB(

                20,

                16,

                20,

                20 + MediaQuery.of(sheetContext).padding.bottom,

              ),

              child: Column(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  const Text(

                    '급여지급일',

                    style: TextStyle(

                      fontSize: 17,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                  const SizedBox(height: 16),

                  const Text(

                    '지급 월',

                    style: TextStyle(

                      fontSize: 13,

                      fontWeight: FontWeight.w600,

                      color: AppColors.textSecondary,

                    ),

                  ),

                  const SizedBox(height: 8),

                  SegmentedButton<SalaryPaymentMonthOffset>(

                    segments: SalaryPaymentMonthOffset.values

                        .map(

                          (o) => ButtonSegment(

                            value: o,

                            label: Text(o.label),

                          ),

                        )

                        .toList(),

                    selected: {selectedOffset},

                    onSelectionChanged: (selection) {

                      setSheetState(

                        () => selectedOffset = selection.first,

                      );

                    },

                  ),

                  const SizedBox(height: 16),

                  const Text(

                    '지급 일',

                    style: TextStyle(

                      fontSize: 13,

                      fontWeight: FontWeight.w600,

                      color: AppColors.textSecondary,

                    ),

                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(

                    value: selectedDay,

                    decoration: InputDecoration(

                      filled: true,

                      fillColor: AppColors.surface,

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(14),

                      ),

                    ),

                    items: List.generate(

                      31,

                      (i) => DropdownMenuItem(

                        value: i + 1,

                        child: Text('${i + 1}일'),

                      ),

                    ),

                    onChanged: (value) {

                      if (value == null) return;

                      setSheetState(() => selectedDay = value);

                    },

                  ),

                  const SizedBox(height: 20),

                  FilledButton(

                    onPressed: () => Navigator.of(sheetContext).pop(true),

                    style: FilledButton.styleFrom(

                      backgroundColor: AppColors.primary,

                      foregroundColor: Colors.white,

                      padding: const EdgeInsets.symmetric(vertical: 14),

                    ),

                    child: const Text('확인'),

                  ),

                ],

              ),

            );

          },

        );

      },

    );



    if (saved == true && context.mounted) {

      onMonthOffsetChanged(selectedOffset);

      onDayOfMonthChanged(selectedDay);

    }

  }



  @override

  Widget build(BuildContext context) {

    return Material(

      color: AppColors.surface,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(

        onTap: () => _openPicker(context),

        borderRadius: BorderRadius.circular(14),

        child: Ink(

          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(14),

            border: Border.all(

              color: _isComplete

                  ? AppColors.primary.withValues(alpha: 0.4)

                  : AppColors.searchBarBorder,

            ),

          ),

          child: Row(

            children: [

              Icon(

                Icons.calendar_view_day_outlined,

                color: _isComplete

                    ? AppColors.primary

                    : AppColors.textSecondary.withValues(alpha: 0.8),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Text(

                  _label,

                  style: TextStyle(

                    fontSize: 15,

                    fontWeight:

                        _isComplete ? FontWeight.w600 : FontWeight.w400,

                    color: _isComplete

                        ? AppColors.textPrimary

                        : AppColors.textSecondary.withValues(alpha: 0.9),

                  ),

                ),

              ),

              const Icon(Icons.chevron_right_rounded,

                  color: AppColors.textSecondary),

            ],

          ),

        ),

      ),

    );

  }

}



class _PushNotificationField extends StatelessWidget {

  const _PushNotificationField({

    required this.settings,

    required this.onTap,

  });



  final JobPostNotificationSettings? settings;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    final configured = settings?.hasConfiguredBase ?? false;



    return Material(

      color: configured
          ? AppColors.surface
          : CorporateServiceActionStyle.setupBackground,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Ink(

          padding: const EdgeInsets.all(14),

          decoration: CorporateServiceActionStyle.setupCardDecoration(
            configured: configured,
          ),

          child: Row(

            children: [

              Icon(

                Icons.notifications_active_outlined,

                color: configured

                    ? AppColors.primary

                    : CorporateServiceActionStyle.setupForeground,

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      configured

                          ? settings!.summaryLabel

                          : '일자리 알림핀 설정하기',

                      style: TextStyle(

                        fontSize: 15,

                        fontWeight: configured

                            ? FontWeight.w600

                            : FontWeight.w500,

                        color: AppColors.textPrimary,

                      ),

                    ),

                    const SizedBox(height: 2),

                    Text(

                      configured

                          ? '탭하여 일자리 알림핀 수정'

                          : '근무지는 무료 · 추가 알림핀은 선택 시 설정',

                      style: TextStyle(

                        fontSize: 12,

                        color: AppColors.textSecondary.withValues(alpha: 0.9),

                      ),

                    ),

                  ],

                ),

              ),

              const Icon(Icons.chevron_right_rounded,

                  color: AppColors.textSecondary),

            ],

          ),

        ),

      ),

    );

  }

}



class FieldLabel extends StatelessWidget {

  const FieldLabel(this.text, {super.key});



  final String text;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Text(

        text,

        style: const TextStyle(

          fontSize: 13,

          fontWeight: FontWeight.w600,

          color: AppColors.textSecondary,

        ),

      ),

    );

  }

}



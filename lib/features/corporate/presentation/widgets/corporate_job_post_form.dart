import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';

import 'package:map/features/corporate/domain/entities/worker_category.dart';

import 'package:map/features/corporate/domain/entities/workplace_address.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';

import 'package:map/core/constants/labor_constants.dart';

import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_selector_field.dart';



/// 일자리 등록·수정 공통 폼

class CorporateJobPostForm extends StatefulWidget {

  const CorporateJobPostForm({

    super.key,

    required this.titleController,

    required this.jobDescriptionController,

    required this.wageController,

    required this.scheduleController,

    required this.summaryController,

    required this.workplace,

    required this.onSearchWorkplace,

    required this.workerCategory,

    required this.onWorkerCategoryChanged,

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

  });



  final TextEditingController titleController;

  final TextEditingController jobDescriptionController;

  final TextEditingController wageController;

  final TextEditingController scheduleController;

  final TextEditingController summaryController;

  final WorkplaceAddress? workplace;

  final VoidCallback onSearchWorkplace;

  final WorkerCategory workerCategory;

  final ValueChanged<WorkerCategory> onWorkerCategoryChanged;

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

        const SizedBox(height: 16),

        const FieldLabel('업무 내용'),

        TextField(

          controller: widget.jobDescriptionController,

          minLines: 3,

          maxLines: 5,

          decoration: _inputDecoration('담당 업무, 근무 조건 등'),

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

        const SizedBox(height: 16),

        const FieldLabel('근무 일정'),

        WorkScheduleSelectorField(controller: widget.scheduleController, dailyOnly: widget.workerCategory == WorkerCategory.daily),

        const SizedBox(height: 16),

        const FieldLabel('급여'),

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
                  widget.wageController.clear();
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

                inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                decoration: _inputDecoration(

                  '예: ${LaborConstants.defaultHourlyWageText}',

                ),

              ),

            ),

          ],

        ),

        const SizedBox(height: 16),

        const FieldLabel('급여지급일'),

        if (widget.workerCategory == WorkerCategory.daily)

          _PaymentDateField(

            paymentDate: widget.paymentDate,

            onTap: widget.onPickPaymentDate,

          )

        else

          _MonthlyPaymentDayField(

            monthOffset: widget.paymentMonthOffset,

            dayOfMonth: widget.paymentDayOfMonth,

            onMonthOffsetChanged: widget.onPaymentMonthOffsetChanged,

            onDayOfMonthChanged: widget.onPaymentDayOfMonthChanged,

          ),

        const SizedBox(height: 16),

        const FieldLabel('내용 추가'),

        TextField(

          controller: widget.summaryController,

          minLines: 3,

          maxLines: 5,

          decoration: _inputDecoration('우대 사항, 복리후생 등'),

        ),

        const SizedBox(height: 16),

        const FieldLabel('공고 노출 범위'),

        Padding(

          padding: const EdgeInsets.only(bottom: 8),

          child: Text(

            '적용 플랜: ${PushPlanEnforcement.planLimitSummary()}',

            style: TextStyle(

              fontSize: 12,

              fontWeight: FontWeight.w600,

              color: AppColors.textSecondary.withValues(alpha: 0.95),

            ),

          ),

        ),

        Padding(

          padding: const EdgeInsets.only(bottom: 8),

          child: Text(

            '무료·보너스 푸시 ${PushPackageCatalog.pushRadiusLabel} · '

            '추가 노출 범위·지원자 모집하기는 패키지 ${PushPlanEnforcement.extraPushPriceKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원/회',

            style: TextStyle(

              fontSize: 11,

              height: 1.35,

              color: AppColors.primary.withValues(alpha: 0.85),

            ),

          ),

        ),

        _PushNotificationField(

          settings: widget.notificationSettings,

          onTap: widget.onConfigurePushNotification,

        ),

        if (widget.beforeSubmit != null) ...[

          const SizedBox(height: 16),

          widget.beforeSubmit!,

        ],

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



class _PaymentDateField extends StatelessWidget {

  const _PaymentDateField({

    required this.paymentDate,

    required this.onTap,

  });



  final DateTime? paymentDate;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    final label = paymentDate == null

        ? '급여 지급일 선택'

        : '${paymentDate!.year}년 ${paymentDate!.month}월 ${paymentDate!.day}일';



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

              color: paymentDate != null

                  ? AppColors.primary.withValues(alpha: 0.4)

                  : AppColors.searchBarBorder,

            ),

          ),

          child: Row(

            children: [

              Icon(

                Icons.calendar_month_outlined,

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

              const Icon(Icons.chevron_right_rounded,

                  color: AppColors.textSecondary),

            ],

          ),

        ),

      ),

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



    final saved = await showModalBottomSheet<bool>(

      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

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

                  Padding(

                    padding: const EdgeInsets.only(top: 8),

                    child: Text(

                      '월마다 일수가 다른 달은 가장 가까운 날에 지급됩니다.',

                      style: TextStyle(

                        fontSize: 11,

                        height: 1.35,

                        color: AppColors.textSecondary.withValues(alpha: 0.9),

                      ),

                    ),

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

      color: AppColors.surface,

      borderRadius: BorderRadius.circular(14),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Ink(

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(14),

            border: Border.all(

              color: configured

                  ? AppColors.primary.withValues(alpha: 0.4)

                  : AppColors.searchBarBorder,

            ),

          ),

          child: Row(

            children: [

              Icon(

                Icons.notifications_active_outlined,

                color: configured

                    ? AppColors.primary

                    : AppColors.textSecondary.withValues(alpha: 0.8),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      configured

                          ? settings!.summaryLabel

                          : '공고 노출 범위 설정하기',

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

                          ? '탭하여 노출 범위 수정 · 초과 모집은 등록 시 추가 구매'

                          : '반경은 플랜별 · 횟수는 기본+추가 구매',

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



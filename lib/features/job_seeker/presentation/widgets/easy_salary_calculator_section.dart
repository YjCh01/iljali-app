import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/job_seeker/domain/services/easy_salary_calculator.dart';

/// 공고 상세 — 쉬운 급여 계산 접이식 섹션
class EasySalaryCalculatorSection extends StatefulWidget {
  const EasySalaryCalculatorSection({super.key, required this.post});

  final CorporateJobPost post;

  @override
  State<EasySalaryCalculatorSection> createState() =>
      _EasySalaryCalculatorSectionState();
}

class _EasySalaryCalculatorSectionState
    extends State<EasySalaryCalculatorSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final estimate = EasySalaryCalculator.estimate(widget.post);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: 20,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '쉬운 급여 계산',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (estimate.hasEstimate)
                    Text(
                      estimate.dailyKrw != null
                          ? '일 ${EasySalaryCalculator.formatKrw(estimate.dailyKrw!)}'
                          : '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: AppColors.primaryLight.withValues(alpha: 0.25),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: estimate.hasEstimate
                  ? _EstimateBody(estimate: estimate)
                  : Text(
                      estimate.note ?? '급여 정보를 확인할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EstimateBody extends StatelessWidget {
  const _EstimateBody({required this.estimate});

  final EasySalaryEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (estimate.hoursPerDay != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '근무 ${estimate.hoursPerDay!.toStringAsFixed(1)}시간 기준 · ${estimate.payType.label}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
        if (estimate.dailyKrw != null)
          _Row(
            label: '예상 일급',
            value: EasySalaryCalculator.formatKrw(estimate.dailyKrw!),
            emphasized: true,
          ),
        if (estimate.weeklyKrw != null) ...[
          const SizedBox(height: 8),
          _Row(
            label: '예상 주급 (주 ${EasySalaryCalculator.weeklyWorkDays}일)',
            value: EasySalaryCalculator.formatKrw(estimate.weeklyKrw!),
          ),
        ],
        if (estimate.monthlyKrw != null) ...[
          const SizedBox(height: 8),
          _Row(
            label: '예상 월급 (월 ${EasySalaryCalculator.monthlyWorkDays}일)',
            value: EasySalaryCalculator.formatKrw(estimate.monthlyKrw!),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '실제 급여는 근무일·수당·세금에 따라 달라질 수 있습니다.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 14 : 13,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 16 : 14,
            fontWeight: FontWeight.w800,
            color: emphasized ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/entities/wage_calculator_input.dart';
import 'package:map/features/job_seeker/domain/entities/wage_calculator_result.dart';
import 'package:map/features/job_seeker/domain/services/easy_salary_calculator.dart';
import 'package:map/features/job_seeker/domain/services/minimum_wage_table.dart';
import 'package:map/features/job_seeker/domain/services/wage_calculator_service.dart';

/// 급여 실수령액 계산기 — 최저임금·주휴수당·연장/야간/휴일수당·4대보험·소득세
/// 산식을 직접 구현한 일용직/상용직 급여 계산기(공공 데이터·법령 기준).
class WageCalculatorPage extends StatefulWidget {
  const WageCalculatorPage({super.key});

  @override
  State<WageCalculatorPage> createState() => _WageCalculatorPageState();
}

class _WageCalculatorPageState extends State<WageCalculatorPage> {
  WageCalcMode _mode = WageCalcMode.daily;
  DailyWageBasis _dailyBasis = DailyWageBasis.hourly;

  final _amountController = TextEditingController();
  final _hoursPerDayController = TextEditingController(text: '8');
  final _overtimeController = TextEditingController(text: '0');
  final _nightController = TextEditingController(text: '0');
  final _holidayController = TextEditingController(text: '0');
  final _weeklyHoursController = TextEditingController(text: '40');
  final _dependentsController = TextEditingController(text: '1');

  bool _hasFiveOrMoreEmployees = true;
  bool _includeWeeklyHolidayAllowance = false;
  bool _showAdvanced = false;

  WageCalculatorResult? _result;

  @override
  void dispose() {
    _amountController.dispose();
    _hoursPerDayController.dispose();
    _overtimeController.dispose();
    _nightController.dispose();
    _holidayController.dispose();
    _weeklyHoursController.dispose();
    _dependentsController.dispose();
    super.dispose();
  }

  double _parseDouble(String text, {double fallback = 0}) {
    return double.tryParse(text.trim()) ?? fallback;
  }

  void _calculate() {
    final amount = EasySalaryCalculator.parseKrw(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('급여 금액을 입력해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final input = WageCalculatorInput(
      mode: _mode,
      amount: amount,
      dailyBasis: _dailyBasis,
      hoursPerDay: _parseDouble(_hoursPerDayController.text, fallback: 8),
      overtimeHours: _parseDouble(_overtimeController.text),
      nightHours: _parseDouble(_nightController.text),
      holidayHours: _parseDouble(_holidayController.text),
      hasFiveOrMoreEmployees: _hasFiveOrMoreEmployees,
      includeWeeklyHolidayAllowance: _includeWeeklyHolidayAllowance,
      weeklyContractHours: _parseDouble(_weeklyHoursController.text, fallback: 40),
      dependents: int.tryParse(_dependentsController.text.trim()) ?? 1,
    );

    setState(() => _result = WageCalculatorService.calculate(input));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text('급여 계산기'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildModeSelector(),
          const SizedBox(height: 16),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mode == WageCalcMode.daily) _buildDailyBasisSelector(),
                if (_mode == WageCalcMode.daily) const SizedBox(height: 12),
                _AmountField(
                  label: _mode == WageCalcMode.monthly
                      ? '월급(세전)'
                      : _dailyBasis == DailyWageBasis.hourly
                          ? '시급'
                          : '일급',
                  controller: _amountController,
                ),
                const SizedBox(height: 12),
                if (_mode == WageCalcMode.daily)
                  _NumberField(
                    label: '하루 근무시간(시간)',
                    controller: _hoursPerDayController,
                  ),
                if (_mode == WageCalcMode.monthly)
                  _NumberField(
                    label: '주 소정근로시간(시간)',
                    controller: _weeklyHoursController,
                  ),
                if (_mode == WageCalcMode.monthly) const SizedBox(height: 12),
                if (_mode == WageCalcMode.monthly)
                  _NumberField(
                    label: '부양가족 수(본인 포함)',
                    controller: _dependentsController,
                  ),
                const SizedBox(height: 8),
                _buildAdvancedSection(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _calculate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('계산하기', style: TextStyle(fontSize: 16)),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(result: _result!),
          ],
          const SizedBox(height: 20),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: '일용직(시급/일급)',
            selected: _mode == WageCalcMode.daily,
            onTap: () => setState(() {
              _mode = WageCalcMode.daily;
              _result = null;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            label: '상용직(월급)',
            selected: _mode == WageCalcMode.monthly,
            onTap: () => setState(() {
              _mode = WageCalcMode.monthly;
              _result = null;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBasisSelector() {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: '시급으로 계산',
            selected: _dailyBasis == DailyWageBasis.hourly,
            compact: true,
            onTap: () => setState(() => _dailyBasis = DailyWageBasis.hourly),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            label: '일급으로 계산',
            selected: _dailyBasis == DailyWageBasis.daily,
            compact: true,
            onTap: () => setState(() => _dailyBasis = DailyWageBasis.daily),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '연장·야간·휴일근무 (선택)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const Spacer(),
                Icon(
                  _showAdvanced
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showAdvanced) ...[
          _NumberField(label: '연장근로시간', controller: _overtimeController),
          const SizedBox(height: 12),
          _NumberField(label: '야간근로시간(22시~06시)', controller: _nightController),
          const SizedBox(height: 12),
          _NumberField(label: '휴일근로시간', controller: _holidayController),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '5인 이상 사업장',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '5인 미만 사업장은 연장·야간·휴일 가산수당이 적용되지 않습니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            value: _hasFiveOrMoreEmployees,
            onChanged: (v) => setState(() => _hasFiveOrMoreEmployees = v),
            activeThumbColor: AppColors.primary,
          ),
          if (_mode == WageCalcMode.daily)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '매주 반복 근무(주휴수당 포함)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '같은 사업장에서 주 15시간 이상 반복 근무하는 경우에만 해당합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              value: _includeWeeklyHolidayAllowance,
              onChanged: (v) =>
                  setState(() => _includeWeeklyHolidayAllowance = v),
              activeThumbColor: AppColors.primary,
            ),
          if (_mode == WageCalcMode.daily && _includeWeeklyHolidayAllowance)
            _NumberField(label: '주 근무시간(시간)', controller: _weeklyHoursController),
        ],
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      '본 계산 결과는 최저임금·근로기준법·소득세법 산식에 따른 추정치입니다. '
      '특히 월급(상용직) 소득세는 국세청 근로소득 간이세액표를 간이 산식으로 근사한 값으로, '
      '실제 원천징수 세액과 다를 수 있습니다. 정확한 금액은 홈택스에서 확인해 주세요.',
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: AppColors.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: compact ? 40 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.searchBarBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '원',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final WageCalculatorResult result;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.isBelowMinimumWage)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '환산 시급 ${EasySalaryCalculator.formatKrw(result.hourlyRate)}은(는) '
                '${MinimumWageTable.latestYear}년 최저임금 '
                '${EasySalaryCalculator.formatKrw(result.minimumWage)}보다 낮습니다.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          Text(
            '실수령액',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            EasySalaryCalculator.formatKrw(result.netPay),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _row('환산 시급', result.hourlyRate),
          _row('기본급', result.basePay),
          if (result.overtimePay > 0) _row('연장근로수당', result.overtimePay),
          if (result.nightPay > 0) _row('야간근로수당', result.nightPay),
          if (result.holidayPay > 0) _row('휴일근로수당', result.holidayPay),
          if (result.weeklyHolidayAllowance > 0)
            _row('주휴수당', result.weeklyHolidayAllowance),
          const SizedBox(height: 8),
          _row('세전 합계', result.grossPay, emphasize: true),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (result.nationalPension > 0) _row('국민연금', -result.nationalPension),
          if (result.healthInsurance > 0) _row('건강보험', -result.healthInsurance),
          if (result.longTermCareInsurance > 0)
            _row('장기요양보험', -result.longTermCareInsurance),
          _row('고용보험', -result.employmentInsurance),
          _row('소득세', -result.incomeTax),
          _row('지방소득세', -result.localIncomeTax),
          const SizedBox(height: 8),
          _row('공제 합계', -result.totalDeduction, emphasize: true),
        ],
      ),
    );
  }

  Widget _row(String label, int amount, {bool emphasize = false}) {
    final isNegative = amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '${isNegative ? '-' : ''}${EasySalaryCalculator.formatKrw(amount.abs())}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: isNegative ? const Color(0xFFD32F2F) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';

class ResumeFieldLabel extends StatelessWidget {
  const ResumeFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFE53935)),
              ),
          ],
        ),
      ),
    );
  }
}

class ResumeDropdownField<T> extends StatelessWidget {
  const ResumeDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null
              ? Text(
                  hint!,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                )
              : null,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text('$item'),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class ResumeTextField extends StatelessWidget {
  const ResumeTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.searchBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.searchBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class ResumeYearRangeField extends StatelessWidget {
  const ResumeYearRangeField({
    super.key,
    required this.startYear,
    required this.endYear,
    required this.onStartChanged,
    required this.onEndChanged,
    this.startHint = '시작',
    this.endHint = '종료',
  });

  final int? startYear;
  final int? endYear;
  final ValueChanged<int?> onStartChanged;
  final ValueChanged<int?> onEndChanged;
  final String startHint;
  final String endHint;

  @override
  Widget build(BuildContext context) {
    final years = SeekerResumeOptions.yearOptions();
    return Row(
      children: [
        Expanded(
          child: ResumeDropdownField<int>(
            value: startYear,
            hint: startHint,
            items: years,
            onChanged: onStartChanged,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('—'),
        ),
        Expanded(
          child: ResumeDropdownField<int>(
            value: endYear,
            hint: endHint,
            items: years,
            onChanged: onEndChanged,
          ),
        ),
      ],
    );
  }
}

class ResumeYearMonthRangeField extends StatelessWidget {
  const ResumeYearMonthRangeField({
    super.key,
    required this.startYear,
    required this.startMonth,
    required this.endYear,
    required this.endMonth,
    required this.onStartYearChanged,
    required this.onStartMonthChanged,
    required this.onEndYearChanged,
    required this.onEndMonthChanged,
    this.startYearHint = '시작',
    this.endYearHint = '종료',
  });

  final int? startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final ValueChanged<int?> onStartYearChanged;
  final ValueChanged<int?> onStartMonthChanged;
  final ValueChanged<int?> onEndYearChanged;
  final ValueChanged<int?> onEndMonthChanged;
  final String startYearHint;
  final String endYearHint;

  @override
  Widget build(BuildContext context) {
    final years = SeekerResumeOptions.yearOptions();
    final months = SeekerResumeOptions.monthOptions;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ResumeDropdownField<int>(
            value: startYear,
            hint: startYearHint,
            items: years,
            onChanged: onStartYearChanged,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: ResumeDropdownField<int>(
            value: startMonth,
            hint: '월',
            items: months,
            onChanged: onStartMonthChanged,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('—'),
        ),
        Expanded(
          flex: 3,
          child: ResumeDropdownField<int>(
            value: endYear,
            hint: endYearHint,
            items: years,
            onChanged: onEndYearChanged,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: ResumeDropdownField<int>(
            value: endMonth,
            hint: '월',
            items: months,
            onChanged: onEndMonthChanged,
          ),
        ),
      ],
    );
  }
}

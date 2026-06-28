import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_permanent_employment_repository.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';
import 'package:map/core/session/auth_session.dart';

Future<PermanentEmploymentRecord?> showRegisterPermanentHireSheet(
  BuildContext context,
  HiringApplication application,
) async {
  final hireDateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final salaryController = TextEditingController(text: '2500000');

  final confirmed = await showAdaptiveSheet<bool>(
    context: context,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '상시직 합격 · 입사일 등록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${application.seekerName} · ${application.postTitle}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hireDateController,
              decoration: const InputDecoration(
                labelText: '입사일 (yyyy-MM-dd)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salaryController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '월 급여 (원)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '입사 후 7일 이내 건강보험 간편인증(네이버·토스·PASS)이 필요합니다.\n'
              '${AppStrings.permanentCommissionNote}',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('등록하기'),
            ),
          ],
        ),
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    hireDateController.dispose();
    salaryController.dispose();
    return null;
  }

  final profile = AuthSession.instance.currentUser?.corporateProfile ??
      await AuthSession.instance.ensureCorporateProfile();
  if (profile == null) {
    hireDateController.dispose();
    salaryController.dispose();
    return null;
  }

  final hireDate = DateTime.tryParse(hireDateController.text.trim());
  final salary =
      int.tryParse(salaryController.text.replaceAll(RegExp(r'[^0-9]'), ''));
  hireDateController.dispose();
  salaryController.dispose();

  if (hireDate == null || salary == null || salary <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입사일과 월 급여를 확인해 주세요.')),
      );
    }
    return null;
  }

  final repo = await LocalPermanentEmploymentRepository.create();
  try {
    return await repo.registerHire(
      applicationId: application.id,
      companyKey: profile.companyKey,
      companyName: profile.companyName,
      seekerEmail: application.seekerEmail,
      seekerName: application.seekerName,
      monthlySalaryKrw: salary,
      hireDate: hireDate,
    );
  } on StateError {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 상시직으로 등록된 지원자입니다.')),
      );
    }
    return null;
  }
}

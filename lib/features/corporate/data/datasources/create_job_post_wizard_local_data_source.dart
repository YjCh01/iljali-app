import 'package:flutter/material.dart';

import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/features/corporate/domain/entities/premium_company.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

abstract class CreateJobPostWizardLocalDataSource {
  Future<List<PremiumCompany>> fetchPremiumCompanies();

  Future<List<JobRoleOption>> fetchJobRoles();
}

class CreateJobPostWizardLocalDataSourceImpl
    implements CreateJobPostWizardLocalDataSource {
  const CreateJobPostWizardLocalDataSourceImpl();

  static const workerTypeQuestion = '어떤 유형의 근로자를 채용하시겠습니까?';

  static const _companies = [
    PremiumCompany(
      id: 'partner_daiso',
      name: '다이소',
      icon: Icons.storefront_outlined,
      brandColor: Color(0xFFE60012),
      brandAccentColor: Colors.white,
      logoMark: 'DAISO',
      logoSubtitle: '다이소',
    ),
    PremiumCompany(
      id: 'partner_coupang_fs',
      name: '쿠팡풀필먼트서비스',
      icon: Icons.local_shipping_outlined,
      brandColor: Color(0xFF0074E9),
      brandAccentColor: Colors.white,
      logoMark: 'COUPANG',
    ),
    PremiumCompany(
      id: 'partner_cj',
      name: 'CJ',
      icon: Icons.apartment_outlined,
      brandColor: Color(0xFFEF151E),
      brandAccentColor: Colors.white,
      logoMark: 'CJ',
      logoSubtitle: 'CJ대한통운',
    ),
  ];

  static const _workerTypes = [
    JobRoleOption(
      id: 'worker_general',
      label: '일반',
      icon: Icons.person_outline_rounded,
    ),
    JobRoleOption(
      id: 'worker_daily',
      label: '일용직',
      icon: Icons.calendar_today_outlined,
    ),
    JobRoleOption(
      id: 'worker_contract',
      label: '계약직',
      icon: Icons.assignment_outlined,
    ),
  ];

  @override
  Future<List<PremiumCompany>> fetchPremiumCompanies() async =>
      List.unmodifiable(_companies);

  @override
  Future<List<JobRoleOption>> fetchJobRoles() async {
    final allowed = ProductFeatureFlags.allowedWorkerCategories;
    return List.unmodifiable(
      _workerTypes.where((role) {
        final category = workerCategoryFromRoleId(role.id);
        return category != null && allowed.contains(category);
      }),
    );
  }
}

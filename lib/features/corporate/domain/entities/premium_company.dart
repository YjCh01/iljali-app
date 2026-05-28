import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

/// 프리미엄 파트너십 기업
class PremiumCompany {
  const PremiumCompany({
    required this.id,
    required this.name,
    required this.icon,
    this.partnershipTier,
    this.brandColor,
    this.brandAccentColor,
    this.logoMark,
    this.logoSubtitle,
  });

  final String id;
  final String name;
  final IconData icon;
  final PremiumPartnershipTier? partnershipTier;
  final Color? brandColor;
  final Color? brandAccentColor;
  final String? logoMark;
  final String? logoSubtitle;

  String? get tierSummary => partnershipTier?.summaryLine;

  bool get hasBrandLogo => brandColor != null && logoMark != null;
}

/// 채용 직무 유형
class JobRoleOption {
  const JobRoleOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// @deprecated Legacy tier enum — runtime uses [PushPackageCatalog] + [EmployerPushWallet] only.
enum PremiumPartnershipTier {
  basic,
  starter,
  growth,
  enterprise,
}

extension PremiumPartnershipTierX on PremiumPartnershipTier {
  String get label => PushPackageCatalog.defaultPlanLabel;

  bool get isPaid => false;

  bool get isEnterprise => this == PremiumPartnershipTier.enterprise;

  int? get monthlyPriceKrwMin => 0;

  int get pushRadiusKm => PushPackageCatalog.freePushRadiusM ~/ 1000;

  int get pushRadiusM => PushPackageCatalog.freePushRadiusM;

  String get pushRadiusLabel => PushPackageCatalog.pushRadiusLabel;

  int get dailyPushLimit => PushPackageCatalog.dailyFreePush;

  String get dailyPushLimitLabel => '${PushPackageCatalog.dailyFreePush}회';

  int get extraPushPriceKrw => PushPackageCatalog.singlePackagePriceKrw;

  int get dailyWorkerSuccessFeeKrwMin => 10000;

  String get dailyWorkerSuccessFeeLabel =>
      PartnershipPlanFormat.krw(dailyWorkerSuccessFeeKrwMin);

  double get permanentWorkerSuccessFeePercentMin => 5.5;

  String get permanentWorkerSuccessFeeLabel => '5.5%';

  int? get designatedPointLimit => PushPackageCatalog.baseLocationSlots;

  int get effectiveMaxPoints => PushPackageCatalog.baseLocationSlots;

  String get summaryLine =>
      '${PushPackageCatalog.defaultPlanLabel} · 0원/월 · '
      '반경 ${PushPackageCatalog.pushRadiusLabel} · '
      '패키지 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}';
}

abstract final class PartnershipPlanFormat {
  static String krw(int amount) => PushPackageCatalog.formatKrw(amount);
  static String krwSuffix(int amount) => PushPackageCatalog.krwSuffix(amount);
}

abstract final class PartnershipPlanDefaults {
  static PremiumPartnershipTier get activePlan => PremiumPartnershipTier.basic;
}

abstract final class PremiumPartnershipPlans {
  static const questionText = '일자리 프로모션 제휴사이신가요?';
  static const pushStrategyNote =
      '기본 1km·하루 1회 · 패키지 5,000원 = 노출 범위 1 + 모집 1회 (1km) · 번들 할인';
  static const commissionSavingsNote =
      '일용직 출근비 1만원 · 상시직 채용 수수료 5.5% (플랜과 무관)';

  static String buildChatNoticeBody() {
    final buffer = StringBuffer()
      ..writeln('안녕하세요, 일자리 운영팀입니다.')
      ..writeln('공고 노출·모집 패키지 요금 안내드립니다.')
      ..writeln()
      ..writeln('■ 기본 플랜 (무료)')
      ..writeln('· 공고 등록 무료')
      ..writeln('· 푸시 반경 ${PushPackageCatalog.pushRadiusLabel} · 하루 ${PushPackageCatalog.dailyFreePush}회')
      ..writeln('· 가입 보너스 ${PushPackageCatalog.signupBonusPushes}회')
      ..writeln()
      ..writeln('■ 공고 노출·모집 패키지 — ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}')
      ..writeln('· 공고 노출 범위 1곳 + 지원자 모집하기 1회 (1km)')
      ..writeln('· 10회 ${PushPackageCatalog.krwSuffix(45000)} / '
          '30회 ${PushPackageCatalog.krwSuffix(120000)} / '
          '100회 ${PushPackageCatalog.krwSuffix(350000)}');
    return buffer.toString();
  }
}

String formatKrw(int amount) => PartnershipPlanFormat.krw(amount);

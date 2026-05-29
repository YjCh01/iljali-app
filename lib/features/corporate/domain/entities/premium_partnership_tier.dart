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
      '근무지 ${PushPackageCatalog.pushRadiusLabel} 무료 푸시(일 1회) · '
      '지역 푸시권 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}';
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
      '공고 등록은 완전 무료입니다. 근무지 1km 무료 푸시(일 1회) 이후 '
      '추가 모집지역은 지역 푸시권(5,000원/회)으로 이용할 수 있습니다.';
  static const commissionSavingsNote =
      '일용직 출근비 1만원 · 상시직 채용 수수료 5.5% (플랜과 무관)';

  static String buildChatNoticeBody() {
    final buffer = StringBuffer()
      ..writeln('안녕하세요, 일자리 운영팀입니다.')
      ..writeln('공고 등록/푸시 정책 안내드립니다.')
      ..writeln()
      ..writeln('■ 공고 등록')
      ..writeln('· 완전 무료')
      ..writeln('· 사업자번호당 동시 활성 공고 최대 10개')
      ..writeln()
      ..writeln('■ 무료 푸시')
      ..writeln('· 근무지 ${PushPackageCatalog.pushRadiusLabel} · 하루 ${PushPackageCatalog.dailyFreePush}회')
      ..writeln()
      ..writeln('■ 유료 지역 푸시권 — ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}')
      ..writeln('· 모집지역 1곳 푸시 1회')
      ..writeln('· 10회 ${PushPackageCatalog.krwSuffix(45000)} / '
          '30회 ${PushPackageCatalog.krwSuffix(120000)} / '
          '100회 ${PushPackageCatalog.krwSuffix(350000)}')
      ..writeln('· 황금핀(◆)은 100회 팩 구매자 전용');
    return buffer.toString();
  }
}

String formatKrw(int amount) => PartnershipPlanFormat.krw(amount);

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

  int get extraPushPriceKrw => PushPackageCatalog.singlePackagePriceKrw;

  /// 일용직 — 1인당 채용 수수료 (제휴 채널·`ENABLE_HIRING_COMMISSION` 활성 시)
  int get dailyWorkerSuccessFeeKrwMin => 15000;

  String get dailyWorkerSuccessFeeLabel =>
      PartnershipPlanFormat.krw(dailyWorkerSuccessFeeKrwMin);

  double get permanentWorkerSuccessFeePercentMin => 5.5;

  String get permanentWorkerSuccessFeeLabel => '5.5%';

  int? get designatedPointLimit => PushPackageCatalog.baseLocationSlots;

  int get effectiveMaxPoints => PushPackageCatalog.baseLocationSlots;

  String get summaryLine => '${PushPackageCatalog.defaultPlanLabel} · 0원/월 · '
      '공고 등록 무료 · '
      '일자리 알림핀 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}';
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
  static const pushStrategyNote = '근무지 주변 700m 반경은 무료로 노출됩니다. '
      '일자리 알림핀·PUSH 알림권은 이용권 구매로 확장할 수 있습니다. '
      '가입 보너스 ${PushPackageCatalog.signupBonusPushes}회 · '
      '사업자 검증 보너스 ${PushPackageCatalog.verificationBonusPushes}회.';
  /// 제휴 채널(`ENABLE_HIRING_COMMISSION=true`) 전용 — 메인 앱 UI에 노출하지 않음
  static const commissionSavingsNote =
      '제휴 채널: 일용직 출근비 15,000원 · 상시직 채용 수수료 5.5% (별도 안내)';

  static String buildChatNoticeBody() {
    final buffer = StringBuffer()
      ..writeln('안녕하세요, 일자리 운영팀입니다.')
      ..writeln('공고 등록/PUSH 정책 안내드립니다.')
      ..writeln()
      ..writeln('■ 공고 등록')
      ..writeln('· 완전 무료')
      ..writeln('· 사업자번호당 동시 활성 공고 최대 10개')
      ..writeln()
      ..writeln('■ 가입·검증 보너스')
      ..writeln(
          '· 가입 ${PushPackageCatalog.signupBonusPushes}회 · 검증 ${PushPackageCatalog.verificationBonusPushes}회 일자리 알림핀')
      ..writeln()
      ..writeln(
          '■ 일자리 알림핀 — ${PushPackageCatalog.krwSuffix(PushPackageCatalog.singlePackagePriceKrw)}')
      ..writeln('· ${PushPackageCatalog.exposureDescription}')
      ..writeln(
          '· 노출+PUSH ${PushPackageCatalog.krwSuffix(PushPackageCatalog.exposureWithPushUnitPriceKrw)} · '
          '10회 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pack10Price(PushPackageCatalog.exposureWithPushUnitPriceKrw))}')
      ..writeln(
          '· PUSH 알림권 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pushOnlyUnitPriceKrw)} · '
          '10회 ${PushPackageCatalog.krwSuffix(PushPackageCatalog.pack10Price(PushPackageCatalog.pushOnlyUnitPriceKrw))}');
    return buffer.toString();
  }
}

String formatKrw(int amount) => PartnershipPlanFormat.krw(amount);

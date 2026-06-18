import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// PUSH 알림권 — 알림핀·정류장 표시핀 1곳 선택 후 PUSH만 (노출 활성화와 별도)
abstract final class PushTicketCatalog {
  static const productName = PushPackageCatalog.pushTicketProductName;

  static const unitPriceKrw = PushPackageCatalog.pushOnlyUnitPriceKrw;

  static const unitDescription = PushPackageCatalog.pushOnlyDescription;

  static String get unitPriceLabel => PushPackageCatalog.krwSuffix(unitPriceKrw);

  static String get priceLine =>
      '$productName · $unitDescription · $unitPriceLabel';

  static int get pack10PriceKrw =>
      PushPackageCatalog.pack10Price(PushPackageCatalog.pushOnlyUnitPriceKrw);
}

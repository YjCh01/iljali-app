import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/dev/qc_demo_addresses.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/usecases/search_workplace_address_usecase.dart';

/// 도로명·텍스트 주소 → [WorkplaceAddress] (좌표 포함)
abstract final class WorkplaceAddressResolver {
  static Future<WorkplaceAddress?> resolve(String rawAddress) async {
    final trimmed = rawAddress.trim();
    if (trimmed.isEmpty || QcDemoAddresses.isLegacyDemo(trimmed)) {
      return null;
    }

    final search = SearchWorkplaceAddressUseCase();
    final result = await search(trimmed);
    if (result.addresses.isNotEmpty) {
      final exact = result.addresses.firstWhere(
        (item) => _normalized(item.roadAddress) == _normalized(trimmed),
        orElse: () => result.addresses.first,
      );
      if (exact.coordinate != null) return exact;
      if (exact.roadAddress.isNotEmpty) {
        final coord = await AddressGeocoder.geocode(exact.roadAddress);
        if (coord != null) {
          return WorkplaceAddress(
            roadAddress: exact.roadAddress,
            jibunAddress: exact.jibunAddress,
            dongName: exact.dongName,
            coordinate: coord,
          );
        }
      }
      return exact.coordinate != null ? exact : null;
    }

    final coordinate = await AddressGeocoder.geocode(trimmed);
    if (coordinate == null) return null;
    return WorkplaceAddress(
      roadAddress: trimmed,
      coordinate: coordinate,
    );
  }

  static String _normalized(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

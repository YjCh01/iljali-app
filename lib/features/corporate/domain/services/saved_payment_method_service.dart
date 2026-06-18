import 'dart:math';

import 'package:map/features/corporate/data/repositories/saved_payment_method_repository.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';

/// 저장 카드 등록 — MVP mock 빌링키 (추후 PG billing API 연동)
class SavedPaymentMethodService {
  SavedPaymentMethodService({SavedPaymentMethodRepository? repository})
      : _repository = repository;

  SavedPaymentMethodRepository? _repository;

  Future<SavedPaymentMethodRepository> _repo() async =>
      _repository ??= await SavedPaymentMethodRepository.create();

  Future<List<SavedPaymentMethod>> listForCompany(String companyKey) async {
    return (await _repo()).listForCompany(companyKey);
  }

  Future<SavedPaymentMethod?> defaultForCompany(String companyKey) async {
    return (await _repo()).findDefault(companyKey);
  }

  Future<SavedPaymentMethod> registerMockCard({
    required String companyKey,
    required String registeredByEmail,
    required String cardBrand,
    required String last4,
  }) async {
    final digits = last4.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 4) {
      throw StateError('invalid_last4');
    }
    final id = 'card-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final billingKey = 'BILLING-$id';
    final method = SavedPaymentMethod(
      id: id,
      companyKey: companyKey.trim(),
      label: '$cardBrand ****$digits',
      cardBrand: cardBrand.trim(),
      last4: digits,
      billingKey: billingKey,
      registeredAt: DateTime.now(),
      registeredByEmail: registeredByEmail.trim(),
    );
    return (await _repo()).add(method);
  }

  Future<bool> removeCard({
    required String companyKey,
    required String id,
  }) async {
    return (await _repo()).remove(companyKey: companyKey, id: id);
  }

  Future<bool> setDefault({
    required String companyKey,
    required String id,
  }) async {
    return (await _repo()).setDefault(companyKey: companyKey, id: id);
  }

  Future<SavedPaymentMethod?> findById({
    required String companyKey,
    required String id,
  }) async {
    return (await _repo()).findById(companyKey: companyKey, id: id);
  }
}

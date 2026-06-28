import 'package:flutter/foundation.dart';
import 'package:map/features/job_seeker/domain/entities/closed_ghost_pin.dart';

abstract class ClosedGhostPinLocalDataSource {
  Future<List<ClosedGhostPin>> fetchAll();
}

class ClosedGhostPinLocalDataSourceImpl implements ClosedGhostPinLocalDataSource {
  const ClosedGhostPinLocalDataSourceImpl();

  static final List<ClosedGhostPin> _pins = [];

  @visibleForTesting
  static void clearInMemoryStoreForTest() => _pins.clear();

  static void replaceFromServer(List<ClosedGhostPin> pins) {
    _pins
      ..clear()
      ..addAll(pins);
  }

  static void upsertLocal(ClosedGhostPin pin) {
    final index = _pins.indexWhere((item) => item.id == pin.id);
    if (index == -1) {
      _pins.add(pin);
      return;
    }
    _pins[index] = pin;
  }

  static void removeLocal(String id) {
    _pins.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<ClosedGhostPin>> fetchAll() async => List.unmodifiable(_pins);
}

import 'package:map/features/job_seeker/domain/entities/event_map_pin.dart';

abstract class EventMapPinLocalDataSource {
  Future<List<EventMapPin>> fetchAll();
}

class EventMapPinLocalDataSourceImpl implements EventMapPinLocalDataSource {
  const EventMapPinLocalDataSourceImpl();

  static final List<EventMapPin> _pins = [];

  static void replaceFromServer(List<EventMapPin> pins) {
    _pins
      ..clear()
      ..addAll(pins);
  }

  static void upsertLocal(EventMapPin pin) {
    final index = _pins.indexWhere((p) => p.id == pin.id);
    if (index >= 0) {
      _pins[index] = pin;
    } else {
      _pins.add(pin);
    }
  }

  static void removeLocal(String id) {
    _pins.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<EventMapPin>> fetchAll() async =>
      List.unmodifiable(_pins.where((p) => p.active));
}

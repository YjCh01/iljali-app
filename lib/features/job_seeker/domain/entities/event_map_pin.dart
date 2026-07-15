/// 어드민 이벤트핑 — 퀴즈·투표·안내
class EventMapPin {
  const EventMapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title = '',
    this.body = '',
    this.kind = EventPinKind.info,
    this.colorHex = '#FF6F00',
    this.options = const [],
    this.correctIndex,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String body;
  final EventPinKind kind;
  final String colorHex;
  final List<String> options;
  final int? correctIndex;
  final bool active;
  final DateTime? createdAt;

  factory EventMapPin.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final payloadMap =
        payload is Map ? Map<String, dynamic>.from(payload) : const <String, dynamic>{};
    final optionsRaw = payloadMap['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    final correct = payloadMap['correct_index'];
    return EventMapPin(
      id: json['id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: EventPinKindX.parse(json['kind'] as String?),
      colorHex: json['color_hex'] as String? ?? '#FF6F00',
      options: options,
      correctIndex: correct is int ? correct : int.tryParse('$correct'),
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'title': title,
        'body': body,
        'kind': kind.name,
        'color_hex': colorHex,
        'payload': {
          'options': options,
          if (correctIndex != null) 'correct_index': correctIndex,
        },
        'active': active,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

enum EventPinKind { info, quiz, vote }

extension EventPinKindX on EventPinKind {
  String get label => switch (this) {
        EventPinKind.info => '안내',
        EventPinKind.quiz => '퀴즈',
        EventPinKind.vote => '투표',
      };

  static EventPinKind parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'quiz':
        return EventPinKind.quiz;
      case 'vote':
        return EventPinKind.vote;
      default:
        return EventPinKind.info;
    }
  }
}

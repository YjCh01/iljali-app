import 'package:map/features/chat/domain/entities/admin_announcement_audience.dart';

/// 어드민 → 이용자 운영 공지
class AdminAnnouncement {
  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.audience = AdminAnnouncementAudience.all,
    this.pushRequested = true,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final AdminAnnouncementAudience audience;
  final bool pushRequested;
  final DateTime? createdAt;

  String get previewLine {
    final line = body.replaceAll('\n', ' ').trim();
    if (line.length <= 72) return line;
    return '${line.substring(0, 72)}…';
  }

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) {
    return AdminAnnouncement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      audience: AdminAnnouncementAudienceX.fromApi(
        json['audience'] as String?,
      ),
      pushRequested: json['push_requested'] == true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'audience': audience.apiValue,
        'push_requested': pushRequested,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

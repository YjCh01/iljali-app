/// 구직자 수신 푸시 — 받은함·보관함
enum SeekerPushInboxFolder {
  inbox,
  archive,
}

extension SeekerPushInboxFolderX on SeekerPushInboxFolder {
  String get label => switch (this) {
        SeekerPushInboxFolder.inbox => '받은 푸시',
        SeekerPushInboxFolder.archive => '보관함',
      };
}

class SeekerPushNotification {
  const SeekerPushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.companyName,
    required this.receivedAt,
    this.jobPostId,
    this.folder = SeekerPushInboxFolder.inbox,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String companyName;
  final String? jobPostId;
  final DateTime receivedAt;
  final SeekerPushInboxFolder folder;
  final bool read;

  bool get isArchived => folder == SeekerPushInboxFolder.archive;

  SeekerPushNotification copyWith({
    String? title,
    String? body,
    String? companyName,
    String? jobPostId,
    DateTime? receivedAt,
    SeekerPushInboxFolder? folder,
    bool? read,
  }) {
    return SeekerPushNotification(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      companyName: companyName ?? this.companyName,
      jobPostId: jobPostId ?? this.jobPostId,
      receivedAt: receivedAt ?? this.receivedAt,
      folder: folder ?? this.folder,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'companyName': companyName,
        'jobPostId': jobPostId,
        'receivedAt': receivedAt.toIso8601String(),
        'folder': folder.name,
        'read': read,
      };

  factory SeekerPushNotification.fromJson(Map<String, dynamic> json) {
    return SeekerPushNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      jobPostId: json['jobPostId'] as String?,
      receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
          DateTime.now(),
      folder: SeekerPushInboxFolder.values.firstWhere(
        (f) => f.name == json['folder'],
        orElse: () => SeekerPushInboxFolder.inbox,
      ),
      read: json['read'] as bool? ?? false,
    );
  }
}

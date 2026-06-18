/// 구직자 공고 보관함 — 사용자 정의 폴더
class JobBookmarkFolder {
  const JobBookmarkFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  static const defaultFolderId = 'default';

  static JobBookmarkFolder defaultFolder([DateTime? now]) {
    final anchor = now ?? DateTime.now();
    return JobBookmarkFolder(
      id: defaultFolderId,
      name: '기본',
      createdAt: anchor,
    );
  }

  JobBookmarkFolder copyWith({
    String? name,
    DateTime? createdAt,
  }) {
    return JobBookmarkFolder(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory JobBookmarkFolder.fromJson(Map<String, dynamic> json) {
    return JobBookmarkFolder(
      id: json['id'] as String? ?? defaultFolderId,
      name: json['name'] as String? ?? '기본',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

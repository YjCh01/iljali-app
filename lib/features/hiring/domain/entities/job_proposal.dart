/// 기업 → 구직자 채용 제안 상태
enum JobProposalStatus {
  pending,
  accepted,
  declined,
  withdrawn;

  String get label => switch (this) {
        JobProposalStatus.pending => '대기',
        JobProposalStatus.accepted => '수락',
        JobProposalStatus.declined => '거절',
        JobProposalStatus.withdrawn => '철회',
      };

  static JobProposalStatus parse(String? raw) {
    if (raw == null) return JobProposalStatus.pending;
    for (final value in JobProposalStatus.values) {
      if (value.name == raw) return value;
    }
    return JobProposalStatus.pending;
  }
}

/// 기업이 활성 공고와 함께 보낸 채용 제안
class JobProposal {
  const JobProposal({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.companyKey,
    required this.companyName,
    required this.seekerEmail,
    required this.seekerDisplayNameMasked,
    required this.status,
    required this.createdAt,
    this.recruiterEmail,
    this.message,
    this.respondedAt,
  });

  final String id;
  final String postId;
  final String postTitle;
  final String companyKey;
  final String companyName;
  final String seekerEmail;
  final String seekerDisplayNameMasked;
  final String? recruiterEmail;
  final String? message;
  final JobProposalStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == JobProposalStatus.pending;

  JobProposal copyWith({
    JobProposalStatus? status,
    DateTime? respondedAt,
  }) {
    return JobProposal(
      id: id,
      postId: postId,
      postTitle: postTitle,
      companyKey: companyKey,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerDisplayNameMasked: seekerDisplayNameMasked,
      recruiterEmail: recruiterEmail,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'postTitle': postTitle,
        'companyKey': companyKey,
        'companyName': companyName,
        'seekerEmail': seekerEmail,
        'seekerDisplayNameMasked': seekerDisplayNameMasked,
        if (recruiterEmail != null) 'recruiterEmail': recruiterEmail,
        if (message != null && message!.isNotEmpty) 'message': message,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      };

  factory JobProposal.fromJson(Map<String, dynamic> json) {
    return JobProposal(
      id: json['id'] as String,
      postId: json['postId'] as String,
      postTitle: json['postTitle'] as String,
      companyName: json['companyName'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String,
      seekerDisplayNameMasked:
          json['seekerDisplayNameMasked'] as String? ?? '구직자',
      recruiterEmail: json['recruiterEmail'] as String?,
      message: json['message'] as String?,
      status: JobProposalStatus.parse(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'] as String)
          : null,
    );
  }
}

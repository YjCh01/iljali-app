/// 구직자 지원 내역
class JobApplication {
  const JobApplication({
    required this.postId,
    required this.title,
    required this.company,
    required this.appliedAt,
    this.status = '접수 완료',
    this.companyKey,
  });

  final String postId;
  final String title;
  final String company;
  final DateTime appliedAt;
  final String status;
  final String? companyKey;

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'title': title,
        'company': company,
        'appliedAt': appliedAt.toIso8601String(),
        'status': status,
        'companyKey': companyKey,
      };

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      postId: json['postId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      appliedAt: DateTime.tryParse(json['appliedAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? '접수 완료',
      companyKey: json['companyKey'] as String?,
    );
  }
}

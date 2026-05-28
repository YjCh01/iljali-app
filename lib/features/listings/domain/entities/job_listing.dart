/// 사용자가 등록한 채용 공고 (로컬 mock)
class JobListing {
  const JobListing({
    required this.id,
    required this.title,
    required this.description,
    required this.warehouseName,
    required this.hourlyWage,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String warehouseName;
  final String hourlyWage;
  final DateTime createdAt;
}

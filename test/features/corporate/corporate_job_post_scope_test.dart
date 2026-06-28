import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/utils/corporate_job_post_scope.dart';
import 'package:map/core/compliance/business_verification_status.dart';

CorporateJobPost _post({
  required String id,
  required String companyKey,
}) {
  return CorporateJobPost(
    id: id,
    title: '테스트 공고',
    warehouseName: '본사',
    hourlyWage: '시급 12000',
    workSchedule: '09:00-18:00',
    summary: '요약',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: DateTime(2026, 1, 1),
    registeredBy: CorporateMemberProfile(
      companyName: 'A사',
      businessRegistrationNumber: companyKey,
      department: '인사',
      contactPersonName: '담당',
      handlerCode: '100001',
      verificationStatus: BusinessVerificationStatus.verified,
    ),
  );
}

void main() {
  setUp(() {
    CorporateJobPostLocalDataSourceImpl.clearInMemoryStoreForTest();
  });

  test('filterForCompany excludes other company posts', () {
    final posts = [
      _post(id: 'a', companyKey: '1111111111'),
      _post(id: 'b', companyKey: '2222222222'),
    ];
    final mine = CorporateJobPostScope.filterForCompany(posts, '1111111111');
    expect(mine.map((p) => p.id).toList(), ['a']);
  });

  test('updateJobPost rejects cross-company mutation', () async {
    const source = CorporateJobPostLocalDataSourceImpl();
    await source.createJobPost(_post(id: 'other', companyKey: '2222222222'));

    expect(
      () => source.updateJobPost(
        _post(id: 'other', companyKey: '2222222222').copyWith(title: '해킹'),
        ownerCompanyKey: '1111111111',
      ),
      throwsA(isA<CorporateJobPostAccessDenied>()),
    );
  });
}

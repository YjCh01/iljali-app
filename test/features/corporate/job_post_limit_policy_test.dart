import 'package:flutter_test/flutter_test.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/utils/job_post_limit_policy.dart';

CorporateJobPost _post(String id, DateTime postedAt, {String brn = '0000000001'}) {
  final expiresAt = postedAt.add(const Duration(days: 30));
  return CorporateJobPost(
    id: id,
    title: id,
    warehouseName: 'w',
    hourlyWage: '10,000원',
    workSchedule: '09-18',
    summary: 's',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 0,
    postedAt: postedAt,
    expiresAt: expiresAt,
    registeredBy: CorporateMemberProfile(
      companyName: 'Test Co',
      businessRegistrationNumber: brn,
      department: 'ops',
      contactPersonName: 'Admin',
      handlerCode: '0001',
    ),
  );
}

void main() {
  test('idsToAutoClose returns empty when under limit', () {
    final base = DateTime.now().subtract(const Duration(hours: 1));
    final posts = List.generate(
      9,
      (i) => _post('p$i', base.add(Duration(minutes: i))),
    );
    expect(
      JobPostLimitPolicy.idsToAutoClose(posts: posts, companyKey: '0000000001'),
      isEmpty,
    );
  });

  test('idsToAutoClose closes oldest when at capacity', () {
    final base = DateTime.now().subtract(const Duration(hours: 1));
    final posts = List.generate(
      10,
      (i) => _post('p$i', base.add(Duration(minutes: i))),
    );
    final toClose = JobPostLimitPolicy.idsToAutoClose(
      posts: posts,
      companyKey: '0000000001',
    );
    expect(toClose, ['p0']);
  });

  test('activePostsForCompany ignores other companies', () {
    final now = DateTime.now();
    final posts = [
      _post('a', now, brn: '0000000001'),
      _post('b', now, brn: '0000000002'),
    ];
    expect(
      JobPostLimitPolicy.activePostsForCompany(posts, '0000000001').map((p) => p.id),
      ['a'],
    );
  });
}

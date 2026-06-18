import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/attendance_proximity_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/services/easy_salary_calculator.dart';

void main() {
  group('EasySalaryCalculator', () {
    test('hourly wage estimates daily weekly monthly', () {
      final post = CorporateJobPost(
        id: 'p1',
        title: '테스트',
        warehouseName: '센터',
        hourlyWage: '시급 10,000원',
        workSchedule: '09:00-18:00',
        summary: '요약',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 1, 1),
      );

      final estimate = EasySalaryCalculator.estimate(post);
      expect(estimate.dailyKrw, 90000);
      expect(estimate.weeklyKrw, 450000);
      expect(estimate.monthlyKrw, 1980000);
      expect(estimate.hoursPerDay, 9);
    });

    test('daily wage field overrides hourly math', () {
      final post = CorporateJobPost(
        id: 'p2',
        title: '일급',
        warehouseName: '센터',
        hourlyWage: '시급 10,000원',
        dailyWage: '120,000원',
        workSchedule: '09:00-18:00',
        summary: '요약',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 1, 1),
      );

      final estimate = EasySalaryCalculator.estimate(post);
      expect(estimate.dailyKrw, 120000);
    });

    test('monthly wage label parses to monthly estimate', () {
      final post = CorporateJobPost(
        id: 'p3',
        title: '월급',
        warehouseName: '센터',
        hourlyWage: '월급 2,200,000원',
        workSchedule: '09:00-18:00',
        summary: '요약',
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: DateTime(2026, 1, 1),
      );

      final estimate = EasySalaryCalculator.estimate(post);
      expect(estimate.monthlyKrw, 2200000);
      expect(estimate.dailyKrw, 100000);
    });
  });

  group('AttendanceProximityService', () {
    const workplace = GeoCoordinate(latitude: 37.5665, longitude: 126.9780);

    test('within 300m triggers prompt', () {
      const nearby = GeoCoordinate(latitude: 37.5678, longitude: 126.9780);
      final result = AttendanceProximityService.evaluate(
        current: nearby,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
      );
      expect(result.shouldPrompt, isTrue);
      expect(result.withinRadius, isTrue);
      expect(result.distanceMeters, lessThan(300));
    });

    test('outside 300m does not prompt', () {
      const far = GeoCoordinate(latitude: 37.5800, longitude: 126.9780);
      final result = AttendanceProximityService.evaluate(
        current: far,
        workplace: workplace,
        ignoreRelaxedPlatform: true,
      );
      expect(result.shouldPrompt, isFalse);
      expect(result.distanceMeters, greaterThan(300));
    });

    test('alert radius is 300m', () {
      expect(AttendanceProximityService.alertRadiusMeters, 300.0);
    });
  });
}

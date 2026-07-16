import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

void main() {
  group('HiringApplicationStatus.wireValue', () {
    test('camelCase members map to snake_case for the server', () {
      expect(HiringApplicationStatus.checkedIn.wireValue, 'checked_in');
      expect(HiringApplicationStatus.commissionPaid.wireValue, 'commission_paid');
      expect(HiringApplicationStatus.noShow.wireValue, 'no_show');
    });

    test('already-lowercase members pass through unchanged', () {
      expect(HiringApplicationStatus.inquiry.wireValue, 'inquiry');
      expect(HiringApplicationStatus.applied.wireValue, 'applied');
      expect(HiringApplicationStatus.chatting.wireValue, 'chatting');
      expect(HiringApplicationStatus.scheduled.wireValue, 'scheduled');
      expect(HiringApplicationStatus.rejected.wireValue, 'rejected');
    });

    test('matches the snake_case values the server actually filters on', () {
      // server/app/services/shuttle_commute_service.py:
      //   JobApplicationRow.status.in_(["scheduled", "checked_in", "commission_paid"])
      const serverEligibleStatuses = {'scheduled', 'checked_in', 'commission_paid'};
      const clientEligibleStatuses = {
        HiringApplicationStatus.scheduled,
        HiringApplicationStatus.checkedIn,
        HiringApplicationStatus.commissionPaid,
      };
      expect(
        clientEligibleStatuses.map((s) => s.wireValue).toSet(),
        serverEligibleStatuses,
      );
    });
  });

  group('hiringApplicationStatusFromWire', () {
    test('reverses wireValue for every status', () {
      for (final status in HiringApplicationStatus.values) {
        expect(hiringApplicationStatusFromWire(status.wireValue), status);
      }
    });

    test('returns null for unknown or missing values', () {
      expect(hiringApplicationStatusFromWire('not_a_status'), isNull);
      expect(hiringApplicationStatusFromWire(null), isNull);
    });
  });
}

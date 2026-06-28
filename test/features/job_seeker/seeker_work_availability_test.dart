import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_work_availability.dart';
import 'package:map/features/job_seeker/domain/services/seeker_availability_matcher.dart';

void main() {
  test('SeekerWorkAvailability encodes and decodes slots', () {
    const availability = SeekerWorkAvailability(
      slots: [
        SeekerAvailabilitySlot(weekday: 0, startMinutes: 540, endMinutes: 720),
        SeekerAvailabilitySlot(weekday: 5, anyTime: true),
      ],
    );

    final decoded = SeekerWorkAvailability.decode(availability.encode());
    expect(decoded.slots.length, 2);
    expect(decoded.slots[0].weekday, 0);
    expect(decoded.slots[0].startMinutes, 540);
    expect(decoded.slots[1].anyTime, isTrue);
  });

  test('withSlots merges without duplicates', () {
    const base = SeekerWorkAvailability(
      slots: [
        SeekerAvailabilitySlot(weekday: 0, startMinutes: 360, endMinutes: 720),
      ],
    );
    const added = SeekerAvailabilitySlot(
      weekday: 0,
      startMinutes: 360,
      endMinutes: 720,
    );
    const newSlot = SeekerAvailabilitySlot(
      weekday: 1,
      startMinutes: 360,
      endMinutes: 720,
    );

    final merged = base.withSlots([added, newSlot]);
    expect(merged.slots.length, 2);
  });

  test('displayLabel formats time range, overnight, and anyTime', () {
    const slot = SeekerAvailabilitySlot(
      weekday: 2,
      startMinutes: 540,
      endMinutes: 1080,
    );
    expect(slot.displayLabel, '수 · 09:00–18:00');

    const overnight = SeekerAvailabilitySlot(
      weekday: 4,
      startMinutes: 21 * 60,
      endMinutes: 7 * 60,
      endDayOffset: 1,
    );
    expect(overnight.displayLabel, '금 · 21:00–07:00 (토)');

    const any = SeekerAvailabilitySlot(weekday: 6, anyTime: true);
    expect(any.displayLabel, '일 · 시간 무관');
  });

  test('matcher covers overnight seeker vs overnight job', () {
    const availability = SeekerWorkAvailability(
      slots: [
        SeekerAvailabilitySlot(
          weekday: 4,
          startMinutes: 21 * 60,
          endMinutes: 7 * 60,
          endDayOffset: 1,
        ),
      ],
    );

    final matches = SeekerAvailabilityMatcher.anySlotCoversJob(
      availability: availability,
      jobWeekday: 4,
      jobStartMinutes: 20 * 60,
      jobEndMinutes: 8 * 60,
      jobEndDayOffset: 1,
    );
    expect(matches, isTrue);
  });
}

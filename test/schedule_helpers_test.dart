import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/utils/schedule_helpers.dart';

void main() {
  group('ScheduleHelpers', () {
    test('parseLine splits day and time', () {
      final parsed = ScheduleHelpers.parseLine('Martes y jueves · 7:00 p.m.');
      expect(parsed.primary, 'Martes y jueves');
      expect(parsed.secondary, '7:00 p.m.');
      expect(parsed.isTimeSlot, isTrue);
    });

    test('parseLine keeps plain text lines', () {
      final parsed = ScheduleHelpers.parseLine('Jelen Tenka');
      expect(parsed.primary, 'Jelen Tenka');
      expect(parsed.secondary, isNull);
      expect(parsed.isLocation, isTrue);
    });
  });
}

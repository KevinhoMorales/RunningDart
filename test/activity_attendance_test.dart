import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/services/qr_service.dart';
import 'package:running_dart/utils/activity_helpers.dart';

void main() {
  group('ActivityHelpers', () {
    test('socialRunStartAt is 19:00 Ecuador (UTC-5)', () {
      final starts = ActivityHelpers.socialRunStartAt(
        year: 2026,
        month: 9,
        day: 10,
      );
      expect(starts.isUtc, isTrue);
      expect(starts.hour, 0);
      expect(starts.day, 11);
      final ecuador = starts.add(ActivityHelpers.ecuadorOffset);
      expect(ecuador.hour, 19);
      expect(ecuador.day, 10);
    });

    test('recurrenceKey distinguishes tue/thu in same week', () {
      final tue = DateTime(2026, 9, 8); // Tuesday
      final thu = DateTime(2026, 9, 10); // Thursday
      expect(tue.weekday, DateTime.tuesday);
      expect(thu.weekday, DateTime.thursday);
      final tueKey = ActivityHelpers.socialRunRecurrenceKey(tue);
      final thuKey = ActivityHelpers.socialRunRecurrenceKey(thu);
      expect(tueKey, contains('-tue'));
      expect(thuKey, contains('-thu'));
      expect(tueKey, isNot(thuKey));
    });

    test('upcomingSocialRunDays returns only tue/thu', () {
      final days = ActivityHelpers.upcomingSocialRunDays(
        weeksAhead: 2,
        now: DateTime.utc(2026, 9, 7, 12), // Monday
      );
      expect(days, isNotEmpty);
      for (final day in days) {
        expect(
          day.weekday == DateTime.tuesday || day.weekday == DateTime.thursday,
          isTrue,
        );
      }
    });
  });

  group('QRService activity check-in', () {
    final qr = QRService();

    test('round-trips activity check-in payload', () {
      final raw = qr.generateActivityCheckInPayload(
        activityId: 'act1',
        token: 'secret',
      );
      final parsed = qr.parseActivityCheckInPayload(raw);
      expect(parsed.activityId, 'act1');
      expect(parsed.token, 'secret');
    });

    test('rejects membership QR as activity check-in', () {
      expect(
        () => qr.parseActivityCheckInPayload(
          '{"userId":"u1","qrCode":"RD-1"}',
        ),
        throwsA(isA<QRParseException>()),
      );
    });

    test('rejects activity QR as membership payload', () {
      final raw = qr.generateActivityCheckInPayload(
        activityId: 'act1',
        token: 'secret',
      );
      expect(() => qr.parsePayload(raw), throwsA(isA<QRParseException>()));
    });
  });
}

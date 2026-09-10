import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/services/notification_service.dart';

void main() {
  group('NotificationService.routeFromMessageData', () {
    test('maps business payload to business detail route', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'business',
          'id': 'abc123',
        }),
        '/business/abc123',
      );
    });

    test('maps news payload to news detail route', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'news',
          'id': 'event-42',
        }),
        '/news/event-42',
      );
    });

    test('maps activity payload to activity detail', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'activity',
          'id': 'run-1',
        }),
        '/activities/run-1',
      );
    });

    test('maps activity_checkin payload to scanner', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'activity_checkin',
          'id': 'run-1',
        }),
        '/activities/run-1/check-in',
      );
    });

    test('maps challenge and league to Liga tab', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'challenge',
          'id': 'ch-1',
        }),
        '/league',
      );
      expect(
        NotificationService.routeFromMessageData({
          'type': 'league',
          'id': 'any',
        }),
        '/league',
      );
    });

    test('returns null for unknown type', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'visit',
          'id': 'abc',
        }),
        isNull,
      );
    });

    test('returns null when id is missing for activity types', () {
      expect(
        NotificationService.routeFromMessageData({'type': 'business'}),
        isNull,
      );
      expect(
        NotificationService.routeFromMessageData({'type': 'activity'}),
        isNull,
      );
    });
  });
}

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

    test('returns null for unknown type', () {
      expect(
        NotificationService.routeFromMessageData({
          'type': 'visit',
          'id': 'abc',
        }),
        isNull,
      );
    });

    test('returns null when id is missing', () {
      expect(
        NotificationService.routeFromMessageData({'type': 'business'}),
        isNull,
      );
    });
  });
}

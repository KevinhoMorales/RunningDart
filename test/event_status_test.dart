import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/utils/helpers.dart';

void main() {
  final today = DateTime(2026, 7, 19);

  group('Helpers.eventStatusLabel', () {
    test('returns Finalizado for past events', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 18), today),
        'Finalizado',
      );
    });

    test('returns Hoy for same day', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 19), today),
        'Hoy',
      );
    });

    test('returns Mañana for one day away', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 20), today),
        'Mañana',
      );
    });

    test('returns En X días for 2-6 days', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 22), today),
        'En 3 días',
      );
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 25), today),
        'En 6 días',
      );
    });

    test('returns En 1 semana for 7-13 days', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 7, 26), today),
        'En 1 semana',
      );
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 8, 1), today),
        'En 1 semana',
      );
    });

    test('returns En 2 semanas for 14-20 days', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 8, 3), today),
        'En 2 semanas',
      );
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 8, 8), today),
        'En 2 semanas',
      );
    });

    test('returns En 3 semanas for 21-27 days', () {
      expect(
        Helpers.eventStatusLabel(DateTime(2026, 8, 9), today),
        'En 3 semanas',
      );
    });
  });

  group('Helpers.isEventPast', () {
    test('detects past and upcoming events', () {
      expect(Helpers.isEventPast(DateTime(2026, 7, 18), today), isTrue);
      expect(Helpers.isEventPast(DateTime(2026, 7, 19), today), isFalse);
      expect(Helpers.isEventUpcoming(DateTime(2026, 7, 25), today), isTrue);
    });
  });
}

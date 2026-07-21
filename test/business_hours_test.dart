import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/business_hours.dart';
import 'package:running_dart/models/business_model.dart';
import 'package:running_dart/utils/business_hours_helpers.dart';

void main() {
  const sampleSlot = BusinessHoursSlot(
    weekdays: [1, 2, 3, 4, 5],
    period: BusinessDayPeriod.morning,
    start: TimeOfDay(hour: 7, minute: 0),
    end: TimeOfDay(hour: 12, minute: 0),
  );

  group('BusinessHoursSlot', () {
    test('serializes and parses json', () {
      final json = sampleSlot.toJson();

      expect(json['weekdays'], [1, 2, 3, 4, 5]);
      expect(json['period'], 'morning');
      expect(json['start'], '07:00');
      expect(json['end'], '12:00');

      final restored = BusinessHoursSlot.fromJson(json);
      expect(restored.weekdays, sampleSlot.weekdays);
      expect(restored.period, sampleSlot.period);
      expect(restored.start, sampleSlot.start);
      expect(restored.end, sampleSlot.end);
    });
  });

  group('BusinessHoursHelpers', () {
    test('formats slot with weekdays period and time range', () {
      final formatted = BusinessHoursHelpers.formatSlot(sampleSlot);

      expect(formatted, contains('Lun - Vie'));
      expect(formatted, contains('Mañana'));
      expect(formatted, contains('7:00 a.m.'));
      expect(formatted, contains('12:00 p.m.'));
    });

    test('toDisplaySummary joins multiple slots', () {
      const slots = [
        sampleSlot,
        BusinessHoursSlot(
          weekdays: [1, 2, 3, 4, 5],
          period: BusinessDayPeriod.afternoon,
          start: TimeOfDay(hour: 14, minute: 0),
          end: TimeOfDay(hour: 20, minute: 0),
        ),
      ];

      final summary = BusinessHoursHelpers.toDisplaySummary(slots);

      expect(summary, contains('Mañana'));
      expect(summary, contains('Tarde'));
      expect(summary, contains('|'));
    });

    test('validateSlots requires at least one slot and valid range', () {
      expect(
        BusinessHoursHelpers.validateSlots(const []),
        isNotNull,
      );
      expect(
        BusinessHoursHelpers.validateSlots(const [
          BusinessHoursSlot(
            weekdays: [],
            period: BusinessDayPeriod.morning,
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 12, minute: 0),
          ),
        ]),
        isNotNull,
      );
      expect(
        BusinessHoursHelpers.validateSlots(const [
          BusinessHoursSlot(
            weekdays: [1],
            period: BusinessDayPeriod.morning,
            start: TimeOfDay(hour: 12, minute: 0),
            end: TimeOfDay(hour: 9, minute: 0),
          ),
        ]),
        isNotNull,
      );
      expect(
        BusinessHoursHelpers.validateSlots(const [sampleSlot]),
        isNull,
      );
    });
  });

  group('BusinessModel operatingHours', () {
    test('toFirestore writes operatingHours and summary hours', () {
      const business = BusinessModel(
        id: 'biz-1',
        name: 'Test',
        description: 'Desc',
        address: 'Address',
        phone: '123',
        hours: '',
        operatingHours: BusinessOperatingHours(slots: [sampleSlot]),
        category: 'café',
        benefits: [],
        discount: '10%',
      );

      final firestore = business.toFirestore();

      expect(firestore['hours'], isNotEmpty);
      expect(firestore['operatingHours'], isA<List>());
      expect((firestore['operatingHours'] as List).length, 1);
    });

    test('round-trips operatingHours through json', () {
      final business = BusinessModel(
        id: 'biz-1',
        name: 'Test',
        description: 'Desc',
        address: 'Address',
        phone: '123',
        hours: BusinessHoursHelpers.toDisplaySummary([sampleSlot]),
        operatingHours: const BusinessOperatingHours(slots: [sampleSlot]),
        category: 'café',
        benefits: const [],
        discount: '10%',
      );

      final restored = BusinessModel.fromJson(business.toJson());

      expect(restored.operatingHours.slots.length, 1);
      expect(restored.operatingHours.slots.first.weekdays, [1, 2, 3, 4, 5]);
      expect(restored.hasStructuredHours, isTrue);
    });
  });
}

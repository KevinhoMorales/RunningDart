import 'package:flutter_test/flutter_test.dart';

import 'package:running_dart/utils/league_helpers.dart';

void main() {
  group('LeagueHelpers', () {
    test('currentPeriodKey uses Ecuador month', () {
      // 2026-09-01 00:30 UTC = still August in Ecuador
      final lateAugust = DateTime.utc(2026, 9, 1, 0, 30);
      expect(LeagueHelpers.currentPeriodKey(lateAugust), '2026-08');

      final earlySeptember = DateTime.utc(2026, 9, 1, 6);
      expect(LeagueHelpers.currentPeriodKey(earlySeptember), '2026-09');
    });

    test('periodLabel is Spanish', () {
      expect(LeagueHelpers.periodLabel('2026-09'), 'Septiembre 2026');
      expect(LeagueHelpers.shortPeriodLabel('2026-09'), 'Sep 2026');
    });

    test('standingDocId', () {
      expect(
        LeagueHelpers.standingDocId('2026-09', 'abc'),
        '2026-09_abc',
      );
    });
  });
}

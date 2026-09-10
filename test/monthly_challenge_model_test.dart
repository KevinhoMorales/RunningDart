import 'package:flutter_test/flutter_test.dart';
import 'package:running_dart/models/monthly_challenge_model.dart';
import 'package:running_dart/utils/league_helpers.dart';

void main() {
  group('ChallengeGoalType', () {
    test('round-trips firestore values', () {
      for (final type in ChallengeGoalType.values) {
        expect(
          ChallengeGoalType.fromFirestore(type.firestoreValue),
          type,
        );
      }
    });
  });

  group('LeagueHelpers.periodKeyFor', () {
    test('uses Ecuador calendar month', () {
      // 2026-09-15 12:00 UTC → still September Ecuador (UTC-5)
      final key = LeagueHelpers.periodKeyFor(DateTime.utc(2026, 9, 15, 12));
      expect(key, '2026-09');
    });
  });

  group('ChallengeBadgeMeta', () {
    test('serializes name and icon', () {
      const badge = ChallengeBadgeMeta(
        name: 'Septiembre SAINTS',
        description: 'Completaste el reto',
        iconName: 'emoji_events',
      );
      final map = badge.toFirestore();
      expect(map['name'], 'Septiembre SAINTS');
      expect(map['iconName'], 'emoji_events');
      expect(
        ChallengeBadgeMeta.fromMap(map).name,
        'Septiembre SAINTS',
      );
    });
  });
}

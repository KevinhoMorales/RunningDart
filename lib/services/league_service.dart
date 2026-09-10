import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firebase_paths.dart';
import '../models/league_standing_model.dart';
import '../utils/league_helpers.dart';

class LeagueService {
  LeagueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _standings =>
      FirebasePaths.collection(_firestore, 'league_standings');

  Stream<List<LeagueStandingModel>> watchLeaderboard({
    String? periodKey,
    int limit = 10,
  }) {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    return _standings
        .where('periodKey', isEqualTo: period)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(LeagueStandingModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<LeagueStandingModel?> watchMyStanding({
    required String userId,
    String? periodKey,
  }) {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    return _standings
        .doc(LeagueHelpers.standingDocId(period, userId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }
      return LeagueStandingModel.fromFirestore(doc);
    });
  }

  Future<LeagueStandingModel?> getMyStanding({
    required String userId,
    String? periodKey,
  }) async {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    final doc =
        await _standings.doc(LeagueHelpers.standingDocId(period, userId)).get();
    if (!doc.exists) {
      return null;
    }
    return LeagueStandingModel.fromFirestore(doc);
  }

  /// Posición 1-based: 1 + cantidad con más puntos en el periodo.
  Future<int?> rankForPoints({
    required String periodKey,
    required int points,
  }) async {
    if (points <= 0) {
      return null;
    }
    final aggregate = await _standings
        .where('periodKey', isEqualTo: periodKey)
        .where('points', isGreaterThan: points)
        .count()
        .get();
    return (aggregate.count ?? 0) + 1;
  }

  Future<int> participantCount({String? periodKey}) async {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    final aggregate = await _standings
        .where('periodKey', isEqualTo: period)
        .where('points', isGreaterThan: 0)
        .count()
        .get();
    return aggregate.count ?? 0;
  }

  Future<LeagueSnapshot> loadSnapshot({
    required String userId,
    String? periodKey,
    int leaderboardLimit = 10,
  }) async {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    final leaderboardSnap = await _standings
        .where('periodKey', isEqualTo: period)
        .orderBy('points', descending: true)
        .limit(leaderboardLimit)
        .get();
    final leaderboard = leaderboardSnap.docs
        .map(LeagueStandingModel.fromFirestore)
        .toList(growable: false);

    final mine = await getMyStanding(userId: userId, periodKey: period);
    final myPoints = mine?.points ?? 0;

    int? rank;
    if (myPoints > 0) {
      final onBoard = leaderboard.indexWhere((s) => s.userId == userId);
      if (onBoard >= 0) {
        rank = onBoard + 1;
      } else {
        rank = await rankForPoints(periodKey: period, points: myPoints);
      }
    }

    final participants = await participantCount(periodKey: period);

    return LeagueSnapshot(
      periodKey: period,
      leaderboard: leaderboard,
      myStanding: mine,
      myRank: rank,
      participantCount: participants,
    );
  }

  /// Ranking admin (más filas).
  Future<List<LeagueStandingModel>> loadFullRanking({
    String? periodKey,
    int limit = 100,
  }) async {
    final period = periodKey ?? LeagueHelpers.currentPeriodKey();
    final snap = await _standings
        .where('periodKey', isEqualTo: period)
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LeagueStandingModel.fromFirestore).toList(growable: false);
  }
}

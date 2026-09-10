import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../models/challenge_progress_model.dart';
import '../models/monthly_challenge_model.dart';
import '../utils/league_helpers.dart';
import '../utils/user_messages.dart';

class ChallengeException implements Exception {
  ChallengeException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChallengeService {
  ChallengeService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _challenges =>
      FirebasePaths.collection(_firestore, 'monthly_challenges');

  CollectionReference<Map<String, dynamic>> get _progress =>
      FirebasePaths.collection(_firestore, 'challenge_progress');

  CollectionReference<Map<String, dynamic>> get _badges =>
      FirebasePaths.collection(_firestore, 'user_badges');

  Stream<List<MonthlyChallengeModel>> watchAllChallenges() {
    return _challenges.orderBy('startsAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map(MonthlyChallengeModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<MonthlyChallengeModel?> watchActiveChallenge() {
    return _challenges.where('status', isEqualTo: 'active').snapshots().map(
      (snap) {
        final now = DateTime.now();
        final matches = snap.docs
            .map(MonthlyChallengeModel.fromFirestore)
            .where((c) => !now.isBefore(c.startsAt) && !now.isAfter(c.endsAt))
            .toList(growable: false);
        if (matches.isEmpty) return null;
        matches.sort((a, b) => b.startsAt.compareTo(a.startsAt));
        return matches.first;
      },
    );
  }

  Future<MonthlyChallengeModel?> getChallenge(String id) async {
    final doc = await _challenges.doc(id).get();
    if (!doc.exists) return null;
    return MonthlyChallengeModel.fromFirestore(doc);
  }

  Future<String> createChallenge(MonthlyChallengeModel challenge) async {
    final ref = _challenges.doc();
    final now = DateTime.now();
    await ref.set(
      challenge
          .copyWith(
            id: ref.id,
            createdAt: now,
            updatedAt: now,
            periodKey: challenge.periodKey ??
                LeagueHelpers.periodKeyFor(challenge.startsAt),
          )
          .toFirestore(),
    );
    return ref.id;
  }

  Future<void> updateChallenge(MonthlyChallengeModel challenge) async {
    final data = challenge.copyWith(updatedAt: DateTime.now()).toFirestore();
    data.remove('createdAt');
    if (challenge.description == null || challenge.description!.isEmpty) {
      data['description'] = FieldValue.delete();
    }
    await _challenges.doc(challenge.id).update(data);
  }

  Future<void> setChallengeStatus({
    required String challengeId,
    required ChallengeStatus status,
  }) async {
    await _challenges.doc(challengeId).update({
      'status': status.firestoreValue,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      if (status == ChallengeStatus.closed)
        'closedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<ChallengeProgressModel?> watchMyProgress({
    required String challengeId,
    required String userId,
  }) {
    return _progress.doc('${challengeId}_$userId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChallengeProgressModel.fromFirestore(doc);
    });
  }

  Stream<List<ChallengeProgressModel>> watchFinishers(String challengeId) {
    return _progress
        .where('challengeId', isEqualTo: challengeId)
        .where('completed', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ChallengeProgressModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<UserBadgeModel>> watchUserBadges(String userId) {
    return _badges
        .where('userId', isEqualTo: userId)
        .orderBy('awardedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(UserBadgeModel.fromFirestore).toList(growable: false),
        );
  }

  Future<void> evaluateMyProgress() async {
    try {
      final callable = _functions.httpsCallable('evaluateMyChallengeProgress');
      await callable.call({
        'environment': AppEnvironment.current.name,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException(UserMessages.functions(e));
    }
  }

  Future<void> setWinners({
    required String challengeId,
    required List<String> winnerUserIds,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminSetChallengeWinners');
      await callable.call({
        'environment': AppEnvironment.current.name,
        'challengeId': challengeId,
        'winnerUserIds': winnerUserIds,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ChallengeException(UserMessages.functions(e));
    }
  }

  /// Enrich finishers with current league points for sorting winners.
  Future<List<ChallengeProgressModel>> finishersWithLeagueRank({
    required String challengeId,
    required String periodKey,
  }) async {
    final snap = await _progress
        .where('challengeId', isEqualTo: challengeId)
        .where('completed', isEqualTo: true)
        .get();
    final standings = FirebasePaths.collection(_firestore, 'league_standings');
    final enriched = <ChallengeProgressModel>[];

    for (final doc in snap.docs) {
      final base = ChallengeProgressModel.fromFirestore(doc);
      final standingDoc = await standings
          .doc(LeagueHelpers.standingDocId(periodKey, base.userId))
          .get();
      final points =
          standingDoc.exists ? (standingDoc.data()?['points'] as num?)?.toInt() ?? 0 : 0;
      enriched.add(
        ChallengeProgressModel(
          id: base.id,
          challengeId: base.challengeId,
          userId: base.userId,
          displayName: base.displayName,
          periodKey: base.periodKey,
          goalType: base.goalType,
          goalTarget: base.goalTarget,
          currentValue: base.currentValue,
          completed: base.completed,
          completedAt: base.completedAt,
          badgeAwarded: base.badgeAwarded,
          pointsAwarded: base.pointsAwarded,
          completionPointsAwarded: base.completionPointsAwarded,
          isWinner: base.isWinner,
          winnerRank: base.winnerRank,
          qualifiesForOfficialPerk: base.qualifiesForOfficialPerk,
          membershipModality: base.membershipModality,
          leaguePoints: points,
          leagueRank: null,
          updatedAt: base.updatedAt,
        ),
      );
    }

    enriched.sort((a, b) {
      final byPoints = (b.leaguePoints ?? 0).compareTo(a.leaguePoints ?? 0);
      if (byPoints != 0) return byPoints;
      return a.displayName.compareTo(b.displayName);
    });

    // Assign dense ranks for display (ties share explanation for admin).
    var rank = 0;
    var lastPoints = -1;
    final ranked = <ChallengeProgressModel>[];
    for (var i = 0; i < enriched.length; i++) {
      final points = enriched[i].leaguePoints ?? 0;
      if (points != lastPoints) {
        rank = i + 1;
        lastPoints = points;
      }
      ranked.add(
        ChallengeProgressModel(
          id: enriched[i].id,
          challengeId: enriched[i].challengeId,
          userId: enriched[i].userId,
          displayName: enriched[i].displayName,
          periodKey: enriched[i].periodKey,
          goalType: enriched[i].goalType,
          goalTarget: enriched[i].goalTarget,
          currentValue: enriched[i].currentValue,
          completed: enriched[i].completed,
          completedAt: enriched[i].completedAt,
          badgeAwarded: enriched[i].badgeAwarded,
          pointsAwarded: enriched[i].pointsAwarded,
          completionPointsAwarded: enriched[i].completionPointsAwarded,
          isWinner: enriched[i].isWinner,
          winnerRank: enriched[i].winnerRank,
          qualifiesForOfficialPerk: enriched[i].qualifiesForOfficialPerk,
          membershipModality: enriched[i].membershipModality,
          leaguePoints: enriched[i].leaguePoints,
          leagueRank: rank,
          updatedAt: enriched[i].updatedAt,
        ),
      );
    }
    return ranked;
  }
}

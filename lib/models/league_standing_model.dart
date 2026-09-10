import 'package:cloud_firestore/cloud_firestore.dart';

class LeagueStandingModel {
  const LeagueStandingModel({
    required this.id,
    required this.userId,
    required this.periodKey,
    required this.displayName,
    required this.points,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String periodKey;
  final String displayName;
  final int points;
  final DateTime updatedAt;

  factory LeagueStandingModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.now();
    }

    return LeagueStandingModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      periodKey: data['periodKey'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Miembro',
      points: (data['points'] as num?)?.toInt() ?? 0,
      updatedAt: readDate(data['updatedAt']),
    );
  }
}

class LeagueSnapshot {
  const LeagueSnapshot({
    required this.periodKey,
    required this.leaderboard,
    required this.myStanding,
    required this.myRank,
    required this.participantCount,
  });

  final String periodKey;
  final List<LeagueStandingModel> leaderboard;
  final LeagueStandingModel? myStanding;
  final int? myRank;
  final int participantCount;

  int get myPoints => myStanding?.points ?? 0;
}

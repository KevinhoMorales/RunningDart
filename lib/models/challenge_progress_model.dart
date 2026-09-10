import 'package:cloud_firestore/cloud_firestore.dart';

import 'monthly_challenge_model.dart';

class ChallengeProgressModel {
  const ChallengeProgressModel({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.displayName,
    required this.goalType,
    required this.goalTarget,
    required this.currentValue,
    required this.completed,
    required this.updatedAt,
    this.periodKey,
    this.completedAt,
    this.badgeAwarded = false,
    this.pointsAwarded = false,
    this.completionPointsAwarded = 0,
    this.isWinner = false,
    this.winnerRank,
    this.qualifiesForOfficialPerk = false,
    this.membershipModality,
    this.leaguePoints,
    this.leagueRank,
  });

  final String id;
  final String challengeId;
  final String userId;
  final String displayName;
  final String? periodKey;
  final ChallengeGoalType goalType;
  final int goalTarget;
  final int currentValue;
  final bool completed;
  final DateTime? completedAt;
  final bool badgeAwarded;
  final bool pointsAwarded;
  final int completionPointsAwarded;
  final bool isWinner;
  final int? winnerRank;
  final bool qualifiesForOfficialPerk;
  final String? membershipModality;
  final int? leaguePoints;
  final int? leagueRank;
  final DateTime updatedAt;

  double get progressFraction {
    if (goalTarget <= 0) return 0;
    return (currentValue / goalTarget).clamp(0.0, 1.0);
  }

  factory ChallengeProgressModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    DateTime? readOptional(dynamic value) {
      if (value == null) return null;
      return readDate(value);
    }

    return ChallengeProgressModel(
      id: doc.id,
      challengeId: data['challengeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Miembro',
      periodKey: data['periodKey'] as String?,
      goalType: ChallengeGoalType.fromFirestore(data['goalType'] as String?),
      goalTarget: (data['goalTarget'] as num?)?.toInt() ?? 0,
      currentValue: (data['currentValue'] as num?)?.toInt() ?? 0,
      completed: data['completed'] == true,
      completedAt: readOptional(data['completedAt']),
      badgeAwarded: data['badgeAwarded'] == true,
      pointsAwarded: data['pointsAwarded'] == true,
      completionPointsAwarded:
          (data['completionPointsAwarded'] as num?)?.toInt() ?? 0,
      isWinner: data['isWinner'] == true,
      winnerRank: (data['winnerRank'] as num?)?.toInt(),
      qualifiesForOfficialPerk: data['qualifiesForOfficialPerk'] == true,
      membershipModality: data['membershipModality'] as String?,
      leaguePoints: (data['leaguePoints'] as num?)?.toInt(),
      leagueRank: (data['leagueRank'] as num?)?.toInt(),
      updatedAt: readDate(data['updatedAt'] ?? Timestamp.now()),
    );
  }
}

class UserBadgeModel {
  const UserBadgeModel({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.badgeName,
    required this.awardedAt,
    this.periodKey,
    this.badgeDescription,
    this.iconName = 'emoji_events',
    this.colorHex,
  });

  final String id;
  final String userId;
  final String challengeId;
  final String? periodKey;
  final String badgeName;
  final String? badgeDescription;
  final String iconName;
  final String? colorHex;
  final DateTime awardedAt;

  factory UserBadgeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return UserBadgeModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      challengeId: data['challengeId'] as String? ?? '',
      periodKey: data['periodKey'] as String?,
      badgeName: data['badgeName'] as String? ?? 'Insignia',
      badgeDescription: data['badgeDescription'] as String?,
      iconName: data['iconName'] as String? ?? 'emoji_events',
      colorHex: data['colorHex'] as String?,
      awardedAt: readDate(data['awardedAt']),
    );
  }
}

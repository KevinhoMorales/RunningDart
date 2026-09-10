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
    this.officialPerkLabel,
    this.officialPerkDescription,
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
  /// Snapshot of the Official perk at award time (winners who qualify).
  final String? officialPerkLabel;
  final String? officialPerkDescription;
  final int? leaguePoints;
  final int? leagueRank;
  final DateTime updatedAt;

  double get progressFraction {
    if (goalTarget <= 0) return 0;
    return (currentValue / goalTarget).clamp(0.0, 1.0);
  }

  bool get isOfficialModality {
    final m = membershipModality;
    return m == 'official' || m == 'proTeam';
  }

  /// Title to show when this finisher earned the Official perk.
  String? earnedOfficialPerkTitle({String? challengeFallback}) {
    if (!qualifiesForOfficialPerk) return null;
    final snap = officialPerkLabel?.trim();
    if (snap != null && snap.isNotEmpty) return snap;
    final fallback = challengeFallback?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'Perk de Miembro Oficial';
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
      officialPerkLabel: data['officialPerkLabel'] as String?,
      officialPerkDescription: data['officialPerkDescription'] as String?,
      leaguePoints: (data['leaguePoints'] as num?)?.toInt(),
      leagueRank: (data['leagueRank'] as num?)?.toInt(),
      updatedAt: readDate(data['updatedAt'] ?? Timestamp.now()),
    );
  }

  ChallengeProgressModel copyWith({
    String? id,
    String? challengeId,
    String? userId,
    String? displayName,
    String? periodKey,
    ChallengeGoalType? goalType,
    int? goalTarget,
    int? currentValue,
    bool? completed,
    DateTime? completedAt,
    bool? badgeAwarded,
    bool? pointsAwarded,
    int? completionPointsAwarded,
    bool? isWinner,
    int? winnerRank,
    bool? qualifiesForOfficialPerk,
    String? membershipModality,
    String? officialPerkLabel,
    String? officialPerkDescription,
    int? leaguePoints,
    int? leagueRank,
    DateTime? updatedAt,
  }) {
    return ChallengeProgressModel(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      periodKey: periodKey ?? this.periodKey,
      goalType: goalType ?? this.goalType,
      goalTarget: goalTarget ?? this.goalTarget,
      currentValue: currentValue ?? this.currentValue,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      badgeAwarded: badgeAwarded ?? this.badgeAwarded,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      completionPointsAwarded:
          completionPointsAwarded ?? this.completionPointsAwarded,
      isWinner: isWinner ?? this.isWinner,
      winnerRank: winnerRank ?? this.winnerRank,
      qualifiesForOfficialPerk:
          qualifiesForOfficialPerk ?? this.qualifiesForOfficialPerk,
      membershipModality: membershipModality ?? this.membershipModality,
      officialPerkLabel: officialPerkLabel ?? this.officialPerkLabel,
      officialPerkDescription:
          officialPerkDescription ?? this.officialPerkDescription,
      leaguePoints: leaguePoints ?? this.leaguePoints,
      leagueRank: leagueRank ?? this.leagueRank,
      updatedAt: updatedAt ?? this.updatedAt,
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

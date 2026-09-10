import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeStatus {
  draft('draft', 'Borrador'),
  active('active', 'Activo'),
  closed('closed', 'Cerrado');

  const ChallengeStatus(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static ChallengeStatus fromFirestore(String? value) {
    return ChallengeStatus.values.firstWhere(
      (s) => s.firestoreValue == value,
      orElse: () => ChallengeStatus.draft,
    );
  }
}

enum ChallengeGoalType {
  checkIns('check_ins', 'X check-ins en el mes'),
  weeklySocialRuns(
    'weekly_social_runs',
    '≥1 Social Run por semana (N semanas)',
  ),
  tueThuWeeks('tue_thu_weeks', 'Mar + Jue por N semanas'),
  points('points', 'Alcanzar X puntos de liga');

  const ChallengeGoalType(this.firestoreValue, this.displayName);

  final String firestoreValue;
  final String displayName;

  static ChallengeGoalType fromFirestore(String? value) {
    return ChallengeGoalType.values.firstWhere(
      (t) => t.firestoreValue == value,
      orElse: () => ChallengeGoalType.checkIns,
    );
  }

  String targetHint() {
    return switch (this) {
      ChallengeGoalType.checkIns => 'Número de check-ins',
      ChallengeGoalType.weeklySocialRuns => 'Semanas con ≥1 Social Run',
      ChallengeGoalType.tueThuWeeks => 'Semanas con mar+jue',
      ChallengeGoalType.points => 'Puntos de liga del mes',
    };
  }
}

class ChallengeBadgeMeta {
  const ChallengeBadgeMeta({
    required this.name,
    this.description,
    this.iconName = 'emoji_events',
    this.colorHex,
  });

  final String name;
  final String? description;
  final String iconName;
  final String? colorHex;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'iconName': iconName,
      if (colorHex != null && colorHex!.isNotEmpty) 'colorHex': colorHex,
    };
  }

  factory ChallengeBadgeMeta.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const ChallengeBadgeMeta(name: 'Insignia SAINTS');
    }
    return ChallengeBadgeMeta(
      name: data['name'] as String? ?? 'Insignia SAINTS',
      description: data['description'] as String?,
      iconName: data['iconName'] as String? ?? 'emoji_events',
      colorHex: data['colorHex'] as String?,
    );
  }
}

class MonthlyChallengeModel {
  const MonthlyChallengeModel({
    required this.id,
    required this.name,
    required this.status,
    required this.goalType,
    required this.goalTarget,
    required this.startsAt,
    required this.endsAt,
    required this.rewardSpots,
    required this.completionPoints,
    required this.badge,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.periodKey,
    this.createdBy,
    this.winnersCount = 0,
    this.officialPerkLabel,
    this.officialPerkDescription,
  });

  final String id;
  final String name;
  final String? description;
  final ChallengeStatus status;
  final ChallengeGoalType goalType;
  final int goalTarget;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? periodKey;
  final int rewardSpots;
  final int completionPoints;
  final ChallengeBadgeMeta badge;
  final String? createdBy;
  final int winnersCount;
  /// Short title of this month's Official Member Perk (physical/extra prize).
  final String? officialPerkLabel;
  final String? officialPerkDescription;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == ChallengeStatus.active;
  bool get isClosed => status == ChallengeStatus.closed;

  bool get hasOfficialPerkConfigured =>
      officialPerkLabel != null && officialPerkLabel!.trim().isNotEmpty;

  String get officialPerkTitle =>
      hasOfficialPerkConfigured
          ? officialPerkLabel!.trim()
          : 'Perk de Miembro Oficial';

  String get goalSummary => '${goalType.displayName}: $goalTarget';

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'status': status.firestoreValue,
      'goalType': goalType.firestoreValue,
      'goalTarget': goalTarget,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      if (periodKey != null && periodKey!.isNotEmpty) 'periodKey': periodKey,
      'rewardSpots': rewardSpots,
      'completionPoints': completionPoints,
      'badge': badge.toFirestore(),
      if (createdBy != null) 'createdBy': createdBy,
      'winnersCount': winnersCount,
      if (officialPerkLabel != null && officialPerkLabel!.trim().isNotEmpty)
        'officialPerkLabel': officialPerkLabel!.trim(),
      if (officialPerkDescription != null &&
          officialPerkDescription!.trim().isNotEmpty)
        'officialPerkDescription': officialPerkDescription!.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MonthlyChallengeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return MonthlyChallengeModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Reto mensual',
      description: data['description'] as String?,
      status: ChallengeStatus.fromFirestore(data['status'] as String?),
      goalType: ChallengeGoalType.fromFirestore(data['goalType'] as String?),
      goalTarget: (data['goalTarget'] as num?)?.toInt() ?? 1,
      startsAt: readDate(data['startsAt']),
      endsAt: readDate(data['endsAt']),
      periodKey: data['periodKey'] as String?,
      rewardSpots: (data['rewardSpots'] as num?)?.toInt() ?? 0,
      completionPoints: (data['completionPoints'] as num?)?.toInt() ?? 20,
      badge: ChallengeBadgeMeta.fromMap(
        data['badge'] is Map
            ? Map<String, dynamic>.from(data['badge'] as Map)
            : null,
      ),
      createdBy: data['createdBy'] as String?,
      winnersCount: (data['winnersCount'] as num?)?.toInt() ?? 0,
      officialPerkLabel: data['officialPerkLabel'] as String?,
      officialPerkDescription: data['officialPerkDescription'] as String?,
      createdAt: readDate(data['createdAt'] ?? data['startsAt']),
      updatedAt: readDate(data['updatedAt'] ?? data['startsAt']),
    );
  }

  MonthlyChallengeModel copyWith({
    String? id,
    String? name,
    String? description,
    ChallengeStatus? status,
    ChallengeGoalType? goalType,
    int? goalTarget,
    DateTime? startsAt,
    DateTime? endsAt,
    String? periodKey,
    int? rewardSpots,
    int? completionPoints,
    ChallengeBadgeMeta? badge,
    String? createdBy,
    int? winnersCount,
    String? officialPerkLabel,
    String? officialPerkDescription,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDescription = false,
    bool clearOfficialPerkLabel = false,
    bool clearOfficialPerkDescription = false,
  }) {
    return MonthlyChallengeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      status: status ?? this.status,
      goalType: goalType ?? this.goalType,
      goalTarget: goalTarget ?? this.goalTarget,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      periodKey: periodKey ?? this.periodKey,
      rewardSpots: rewardSpots ?? this.rewardSpots,
      completionPoints: completionPoints ?? this.completionPoints,
      badge: badge ?? this.badge,
      createdBy: createdBy ?? this.createdBy,
      winnersCount: winnersCount ?? this.winnersCount,
      officialPerkLabel: clearOfficialPerkLabel
          ? null
          : (officialPerkLabel ?? this.officialPerkLabel),
      officialPerkDescription: clearOfficialPerkDescription
          ? null
          : (officialPerkDescription ?? this.officialPerkDescription),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

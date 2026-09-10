import 'package:cloud_firestore/cloud_firestore.dart';

/// Valores de puntos configurables en `club_settings/points_config`.
class PointsConfigModel {
  const PointsConfigModel({
    this.checkInPoints = defaultCheckInPoints,
    this.weeklyDoubleBonus = defaultWeeklyDoubleBonus,
  });

  static const int defaultCheckInPoints = 10;
  static const int defaultWeeklyDoubleBonus = 5;
  static const String documentId = 'points_config';

  final int checkInPoints;
  final int weeklyDoubleBonus;

  Map<String, dynamic> toFirestore() {
    return {
      'checkInPoints': checkInPoints,
      'weeklyDoubleBonus': weeklyDoubleBonus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PointsConfigModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return const PointsConfigModel();
    }

    return PointsConfigModel(
      checkInPoints: (data['checkInPoints'] as num?)?.toInt() ??
          defaultCheckInPoints,
      weeklyDoubleBonus: (data['weeklyDoubleBonus'] as num?)?.toInt() ??
          defaultWeeklyDoubleBonus,
    );
  }
}

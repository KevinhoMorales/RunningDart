import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../config/app_environment.dart';
import '../config/firebase_paths.dart';
import '../models/activity_checkin_model.dart';
import '../models/activity_model.dart';
import '../models/activity_rsvp_model.dart';
import '../models/activity_type.dart';
import '../models/points_config_model.dart';
import '../utils/activity_helpers.dart';
import '../utils/constants.dart';
import '../utils/user_messages.dart';

class ActivityException implements Exception {
  ActivityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ActivityCheckInResult {
  const ActivityCheckInResult({
    required this.alreadyCheckedIn,
    required this.pointsAwarded,
    required this.bonusAwarded,
    this.message,
  });

  final bool alreadyCheckedIn;
  final int pointsAwarded;
  final int bonusAwarded;
  final String? message;
}

class ActivityService {
  ActivityService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _activities =>
      FirebasePaths.collection(_firestore, 'activities');

  CollectionReference<Map<String, dynamic>> get _rsvps =>
      FirebasePaths.collection(_firestore, 'activity_rsvps');

  CollectionReference<Map<String, dynamic>> get _checkIns =>
      FirebasePaths.collection(_firestore, 'activity_checkins');

  DocumentReference<Map<String, dynamic>> get _pointsConfigRef =>
      FirebasePaths.clubSettingsDocument(
        _firestore,
        PointsConfigModel.documentId,
      );

  Stream<List<ActivityModel>> watchUpcomingActivities({int limit = 30}) {
    final now = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 3)),
    );
    return _activities
        .where('isPublished', isEqualTo: true)
        .where('startsAt', isGreaterThanOrEqualTo: now)
        .orderBy('startsAt')
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<ActivityModel>> watchAllActivitiesForAdmin({int limit = 60}) {
    return _activities
        .orderBy('startsAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<ActivityModel?> getActivity(String id) async {
    final doc = await _activities.doc(id).get();
    if (!doc.exists) {
      return null;
    }
    return ActivityModel.fromFirestore(doc);
  }

  Stream<ActivityModel?> watchActivity(String id) {
    return _activities.doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return ActivityModel.fromFirestore(doc);
    });
  }

  Future<ActivityModel?> getNextActivity() async {
    final now = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 2)),
    );
    final snapshot = await _activities
        .where('isPublished', isEqualTo: true)
        .where('startsAt', isGreaterThanOrEqualTo: now)
        .orderBy('startsAt')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return ActivityModel.fromFirestore(snapshot.docs.first);
  }

  Future<String> createActivity(ActivityModel activity) async {
    final ref = _activities.doc();
    final now = DateTime.now();
    final token = activity.checkInToken ?? _uuid.v4();
    await ref.set(
      activity
          .copyWith(
            id: ref.id,
            createdAt: now,
            updatedAt: now,
          )
          .toFirestore(),
    );
    await _secrets.doc(ref.id).set({
      'activityId': ref.id,
      'token': token,
      'updatedAt': Timestamp.fromDate(now),
    });
    return ref.id;
  }

  CollectionReference<Map<String, dynamic>> get _secrets =>
      FirebasePaths.collection(_firestore, 'activity_checkin_secrets');

  Future<String?> getCheckInToken(String activityId) async {
    final doc = await _secrets.doc(activityId).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data()?['token'] as String?;
  }

  Future<void> updateActivity(ActivityModel activity) async {
    // No pisar contadores denormalizados (los sincroniza Cloud Functions).
    final data = activity.copyWith(updatedAt: DateTime.now()).toFirestore();
    data.remove('confirmedCount');
    data.remove('checkedInCount');
    data.remove('createdAt');
    // Limpiar opcionales cuando el admin los deja vacíos.
    if (activity.capacity == null) {
      data['capacity'] = FieldValue.delete();
    }
    if (activity.pointsOverride == null) {
      data['pointsOverride'] = FieldValue.delete();
    }
    await _activities.doc(activity.id).update(data);
  }

  Future<void> setCheckInWindow({
    required String activityId,
    required bool enabled,
    DateTime? opensAt,
    DateTime? closesAt,
    bool rotateToken = false,
  }) async {
    final updates = <String, dynamic>{
      'checkInEnabled': enabled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (opensAt != null) {
      updates['checkInOpensAt'] = Timestamp.fromDate(opensAt);
    }
    if (closesAt != null) {
      updates['checkInClosesAt'] = Timestamp.fromDate(closesAt);
    }
    await _activities.doc(activityId).update(updates);

    if (rotateToken || enabled) {
      final existing = await getCheckInToken(activityId);
      if (rotateToken || existing == null || existing.isEmpty) {
        await _secrets.doc(activityId).set({
          'activityId': activityId,
          'token': _uuid.v4(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
  }

  /// Crea los Social Runs de martes/jueves faltantes para las próximas semanas.
  Future<int> ensureUpcomingSocialRuns({
    int weeksAhead = 4,
    String? createdBy,
  }) async {
    final days = ActivityHelpers.upcomingSocialRunDays(weeksAhead: weeksAhead);
    var created = 0;
    final now = DateTime.now();

    for (final day in days) {
      final key = ActivityHelpers.socialRunRecurrenceKey(day);
      final existing = await _activities
          .where('recurrenceKey', isEqualTo: key)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        continue;
      }

      final activity = ActivityHelpers.buildSocialRun(
        ecuadorDay: day,
        now: now,
        createdBy: createdBy,
      );
      await createActivity(activity);
      created += 1;
    }
    return created;
  }

  Future<ActivityRsvpModel?> getMyRsvp({
    required String activityId,
    required String userId,
  }) async {
    final doc =
        await _rsvps.doc(ActivityRsvpModel.docId(activityId, userId)).get();
    if (!doc.exists) {
      return null;
    }
    return ActivityRsvpModel.fromFirestore(doc);
  }

  Stream<ActivityRsvpModel?> watchMyRsvp({
    required String activityId,
    required String userId,
  }) {
    return _rsvps
        .doc(ActivityRsvpModel.docId(activityId, userId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }
      return ActivityRsvpModel.fromFirestore(doc);
    });
  }

  Future<void> confirmAttendance({
    required String activityId,
    required String userId,
    required String displayName,
  }) async {
    final now = DateTime.now();
    final id = ActivityRsvpModel.docId(activityId, userId);
    await _rsvps.doc(id).set(
      ActivityRsvpModel(
        id: id,
        activityId: activityId,
        userId: userId,
        displayName: displayName,
        status: ActivityRsvpStatus.confirmed,
        updatedAt: now,
        confirmedAt: now,
      ).toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<void> cancelAttendance({
    required String activityId,
    required String userId,
    required String displayName,
  }) async {
    final now = DateTime.now();
    final id = ActivityRsvpModel.docId(activityId, userId);
    final existing = await getMyRsvp(activityId: activityId, userId: userId);
    await _rsvps.doc(id).set(
      {
        'activityId': activityId,
        'userId': userId,
        'displayName': displayName,
        'status': ActivityRsvpStatus.cancelled.firestoreValue,
        'updatedAt': Timestamp.fromDate(now),
        'cancelledAt': Timestamp.fromDate(now),
        if (existing?.confirmedAt != null)
          'confirmedAt': Timestamp.fromDate(existing!.confirmedAt!),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<ActivityRsvpModel>> watchConfirmedRsvps(String activityId) {
    return _rsvps
        .where('activityId', isEqualTo: activityId)
        .where('status', isEqualTo: ActivityRsvpStatus.confirmed.firestoreValue)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityRsvpModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<ActivityCheckInModel?> watchMyCheckIn({
    required String activityId,
    required String userId,
  }) {
    return _checkIns
        .doc(ActivityCheckInModel.docId(activityId, userId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }
      return ActivityCheckInModel.fromFirestore(doc);
    });
  }

  Stream<List<ActivityCheckInModel>> watchCheckIns(String activityId) {
    return _checkIns
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ActivityCheckInModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<ActivityCheckInResult> checkInWithQr({
    required String activityId,
    required String token,
  }) async {
    try {
      final callable = _functions.httpsCallable('checkInToActivity');
      final result = await callable.call({
        'environment': AppEnvironment.current.name,
        'activityId': activityId,
        'token': token,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return ActivityCheckInResult(
        alreadyCheckedIn: data['alreadyCheckedIn'] == true,
        pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
        bonusAwarded: (data['bonusAwarded'] as num?)?.toInt() ?? 0,
        message: data['message'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw ActivityException(UserMessages.functions(e));
    }
  }

  Future<ActivityCheckInResult> adminMarkCheckIn({
    required String activityId,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminMarkActivityCheckIn');
      final result = await callable.call({
        'environment': AppEnvironment.current.name,
        'activityId': activityId,
        'userId': userId,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return ActivityCheckInResult(
        alreadyCheckedIn: data['alreadyCheckedIn'] == true,
        pointsAwarded: (data['pointsAwarded'] as num?)?.toInt() ?? 0,
        bonusAwarded: (data['bonusAwarded'] as num?)?.toInt() ?? 0,
        message: data['message'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      throw ActivityException(UserMessages.functions(e));
    }
  }

  Future<void> adminRemoveCheckIn({
    required String activityId,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminRemoveActivityCheckIn');
      await callable.call({
        'environment': AppEnvironment.current.name,
        'activityId': activityId,
        'userId': userId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ActivityException(UserMessages.functions(e));
    }
  }

  Future<PointsConfigModel> getPointsConfig() async {
    final doc = await _pointsConfigRef.get();
    if (!doc.exists) {
      return const PointsConfigModel();
    }
    return PointsConfigModel.fromFirestore(doc);
  }

  Future<void> savePointsConfig(PointsConfigModel config) async {
    await _pointsConfigRef.set(config.toFirestore(), SetOptions(merge: true));
  }

  Future<ActivityModel> createManualActivity({
    required String title,
    required ActivityType type,
    required DateTime startsAt,
    String? description,
    String? venue,
    String? location,
    int? capacity,
    int? pointsOverride,
    String? createdBy,
    bool isPublished = true,
  }) {
    final now = DateTime.now();
    final activity = ActivityModel(
      id: '',
      title: title.trim().isEmpty ? type.displayName : title.trim(),
      type: type,
      startsAt: startsAt,
      endsAt: ActivityHelpers.defaultEndsAt(startsAt),
      venue: (venue == null || venue.isEmpty)
          ? AppConstants.clubVenue
          : venue,
      location: (location == null || location.isEmpty)
          ? AppConstants.clubLocation
          : location,
      description: description,
      capacity: capacity,
      pointsOverride: pointsOverride,
      isPublished: isPublished,
      checkInToken: _uuid.v4(),
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
    return createActivity(activity).then((id) => activity.copyWith(id: id));
  }
}

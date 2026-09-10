const { FieldValue } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");
const { collectionFor } = require("./firestore_helpers");

const DEFAULT_CHECK_IN_POINTS = 10;
const DEFAULT_WEEKLY_BONUS = 5;

function assertValidEnvironment(environment) {
  if (environment !== "dev" && environment !== "prod") {
    throw new HttpsError("invalid-argument", "Ambiente inválido.");
  }
}

async function requireAdmin(db, environment, uid) {
  const snap = await collectionFor(db, environment, "users").doc(uid).get();
  if (!snap.exists || snap.data()?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede hacer esto.",
    );
  }
  return snap.data();
}

async function requireActiveUser(db, environment, uid) {
  const snap = await collectionFor(db, environment, "users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "No se encontró tu perfil.");
  }
  const data = snap.data();
  if (data.isActive !== true) {
    throw new HttpsError("permission-denied", "Tu cuenta está desactivada.");
  }
  return { id: uid, ...data };
}

async function getPointsConfig(db, environment) {
  const snap = await collectionFor(db, environment, "club_settings")
    .doc("points_config")
    .get();
  const data = snap.exists ? snap.data() : {};
  return {
    checkInPoints:
      typeof data.checkInPoints === "number"
        ? data.checkInPoints
        : DEFAULT_CHECK_IN_POINTS,
    weeklyDoubleBonus:
      typeof data.weeklyDoubleBonus === "number"
        ? data.weeklyDoubleBonus
        : DEFAULT_WEEKLY_BONUS,
  };
}

/** Semana ISO en hora Ecuador (UTC-5). */
function ecuadorIsoWeekKey(date) {
  const ecuadorMs = date.getTime() - 5 * 60 * 60 * 1000;
  const ecuador = new Date(ecuadorMs);
  // Día civil Ecuador como UTC noon para evitar bordes.
  const utcDate = new Date(
    Date.UTC(
      ecuador.getUTCFullYear(),
      ecuador.getUTCMonth(),
      ecuador.getUTCDate(),
    ),
  );
  // ISO: semana del jueves.
  const dayNum = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((utcDate - yearStart) / 86400000 + 1) / 7);
  return `${utcDate.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function isCheckInWindowOpen(activity, now = new Date()) {
  if (activity.checkInEnabled !== true) {
    return false;
  }
  const opens = activity.checkInOpensAt?.toDate?.() ?? activity.checkInOpensAt;
  const closes =
    activity.checkInClosesAt?.toDate?.() ?? activity.checkInClosesAt;
  if (opens && now < new Date(opens)) {
    return false;
  }
  if (closes && now > new Date(closes)) {
    return false;
  }
  return true;
}

/**
 * Otorga puntos de check-in (+ bonus semanal Mar+Jue si aplica).
 * Idempotente por checkInId y por weekKey de bonus.
 */
async function awardCheckInPoints(db, environment, {
  userId,
  activityId,
  checkInId,
  activityType,
  startsAt,
}) {
  const config = await getPointsConfig(db, environment);
  const pointEvents = collectionFor(db, environment, "point_events");
  const balances = collectionFor(db, environment, "point_balances");
  const checkIns = collectionFor(db, environment, "activity_checkins");

  const checkInEventId = `checkin_${checkInId}`;
  const weekKey = ecuadorIsoWeekKey(
    startsAt instanceof Date ? startsAt : startsAt.toDate(),
  );

  let pointsAwarded = 0;

  await db.runTransaction(async (tx) => {
    const eventRef = pointEvents.doc(checkInEventId);
    const balanceRef = balances.doc(userId);
    const checkInRef = checkIns.doc(checkInId);

    const [existingEvent, balanceSnap] = await Promise.all([
      tx.get(eventRef),
      tx.get(balanceRef),
    ]);

    if (existingEvent.exists) {
      pointsAwarded = existingEvent.data().points || 0;
      return;
    }

    pointsAwarded = config.checkInPoints;
    const current = balanceSnap.exists
      ? balanceSnap.data().totalPoints || 0
      : 0;

    tx.set(eventRef, {
      userId,
      activityId,
      type: "activity_checkin",
      points: pointsAwarded,
      sourceCheckInId: checkInId,
      weekKey,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      balanceRef,
      {
        userId,
        totalPoints: current + pointsAwarded,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    tx.update(checkInRef, {
      pointsAwarded,
      pointEventId: checkInEventId,
    });
  });

  let bonusAwarded = 0;
  if (activityType === "social_run" && config.weeklyDoubleBonus > 0) {
    bonusAwarded = await maybeAwardWeeklyBonus(db, environment, {
      userId,
      activityId,
      weekKey,
      bonusPoints: config.weeklyDoubleBonus,
      excludeCheckInId: checkInId,
    });
  }

  return { pointsAwarded, bonusAwarded, checkInEventId };
}

async function maybeAwardWeeklyBonus(db, environment, {
  userId,
  activityId,
  weekKey,
  bonusPoints,
  excludeCheckInId,
}) {
  const pointEvents = collectionFor(db, environment, "point_events");
  const balances = collectionFor(db, environment, "point_balances");
  const checkIns = collectionFor(db, environment, "activity_checkins");
  const activities = collectionFor(db, environment, "activities");
  const bonusEventId = `weekly_bonus_${userId}_${weekKey}`;

  const existingBonus = await pointEvents.doc(bonusEventId).get();
  if (existingBonus.exists) {
    return existingBonus.data().points || 0;
  }

  const userCheckIns = await checkIns.where("userId", "==", userId).get();
  const otherActivityIds = [
    ...new Set(
      userCheckIns.docs
        .filter((d) => d.id !== excludeCheckInId)
        .map((d) => d.data().activityId)
        .filter(Boolean),
    ),
  ];

  if (otherActivityIds.length === 0) {
    return 0;
  }

  let foundPeer = false;
  for (let i = 0; i < otherActivityIds.length && !foundPeer; i += 10) {
    const chunk = otherActivityIds.slice(i, i + 10);
    const snaps = await Promise.all(chunk.map((id) => activities.doc(id).get()));
    for (const snap of snaps) {
      if (!snap.exists) continue;
      const data = snap.data();
      if (data.type !== "social_run") continue;
      const startsAt = data.startsAt?.toDate?.() ?? data.startsAt;
      if (!startsAt) continue;
      if (ecuadorIsoWeekKey(new Date(startsAt)) === weekKey) {
        foundPeer = true;
        break;
      }
    }
  }

  if (!foundPeer) {
    return 0;
  }

  let awarded = 0;
  await db.runTransaction(async (tx) => {
    const bonusRef = pointEvents.doc(bonusEventId);
    const balanceRef = balances.doc(userId);
    const [again, balanceSnap] = await Promise.all([
      tx.get(bonusRef),
      tx.get(balanceRef),
    ]);
    if (again.exists) {
      awarded = again.data().points || 0;
      return;
    }
    awarded = bonusPoints;
    const current = balanceSnap.exists
      ? balanceSnap.data().totalPoints || 0
      : 0;
    tx.set(bonusRef, {
      userId,
      activityId,
      type: "weekly_bonus",
      points: awarded,
      weekKey,
      note: "Bonus por asistir martes y jueves la misma semana",
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      balanceRef,
      {
        userId,
        totalPoints: current + awarded,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return awarded;
}

async function reverseCheckInPoints(db, environment, {
  userId,
  checkInId,
  checkInEventId,
}) {
  const pointEvents = collectionFor(db, environment, "point_events");
  const balances = collectionFor(db, environment, "point_balances");

  if (!checkInEventId) {
    return;
  }

  await db.runTransaction(async (tx) => {
    const eventRef = pointEvents.doc(checkInEventId);
    const reversalId = `reversal_${checkInEventId}`;
    const reversalRef = pointEvents.doc(reversalId);
    const balanceRef = balances.doc(userId);

    const [eventSnap, reversalSnap, balanceSnap] = await Promise.all([
      tx.get(eventRef),
      tx.get(reversalRef),
      tx.get(balanceRef),
    ]);

    if (!eventSnap.exists || reversalSnap.exists) {
      return;
    }

    const points = eventSnap.data().points || 0;
    const current = balanceSnap.exists
      ? balanceSnap.data().totalPoints || 0
      : 0;

    tx.set(reversalRef, {
      userId,
      type: "reversal",
      points: -points,
      sourceCheckInId: checkInId,
      note: "Reverso de check-in eliminado por admin",
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.delete(eventRef);
    tx.set(
      balanceRef,
      {
        userId,
        totalPoints: current - points,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

async function performCheckIn(db, environment, {
  activityId,
  user,
  method,
  token,
  checkedInBy,
  skipWindowCheck,
}) {
  const activities = collectionFor(db, environment, "activities");
  const checkIns = collectionFor(db, environment, "activity_checkins");
  const activityRef = activities.doc(activityId);
  const activitySnap = await activityRef.get();

  if (!activitySnap.exists) {
    throw new HttpsError("not-found", "No se encontró la actividad.");
  }

  const activity = activitySnap.data();
  const checkInId = `${activityId}_${user.id}`;
  const checkInRef = checkIns.doc(checkInId);
  const existing = await checkInRef.get();

  if (existing.exists) {
    return {
      alreadyCheckedIn: true,
      pointsAwarded: existing.data().pointsAwarded || 0,
      bonusAwarded: 0,
      message: "Ya registraste tu asistencia.",
    };
  }

  if (!skipWindowCheck) {
    if (!isCheckInWindowOpen(activity)) {
      throw new HttpsError(
        "failed-precondition",
        "El check-in no está abierto en este momento.",
      );
    }
    const secretSnap = await collectionFor(
      db,
      environment,
      "activity_checkin_secrets",
    )
      .doc(activityId)
      .get();
    const expectedToken = secretSnap.exists ? secretSnap.data()?.token : null;
    // Compat: token legacy en el doc de actividad.
    const legacyToken = activity.checkInToken;
    if (token !== expectedToken && token !== legacyToken) {
      throw new HttpsError(
        "permission-denied",
        "El código QR de check-in no es válido.",
      );
    }
  }

  const displayName =
    typeof user.displayName === "string" && user.displayName.trim()
      ? user.displayName.trim()
      : "Miembro";

  let createdNow = false;
  await db.runTransaction(async (tx) => {
    const again = await tx.get(checkInRef);
    if (again.exists) {
      return;
    }
    createdNow = true;
    tx.set(checkInRef, {
      activityId,
      userId: user.id,
      displayName,
      checkedInAt: FieldValue.serverTimestamp(),
      method,
      checkedInBy: checkedInBy || null,
      pointsAwarded: 0,
    });
    tx.update(activityRef, {
      checkedInCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const after = await checkInRef.get();
  if (!after.exists) {
    throw new HttpsError("internal", "No se pudo registrar el check-in.");
  }

  if (!createdNow) {
    return {
      alreadyCheckedIn: true,
      pointsAwarded: after.data().pointsAwarded || 0,
      bonusAwarded: 0,
      message: "Ya registraste tu asistencia.",
    };
  }

  const startsAt = activity.startsAt?.toDate?.() ?? new Date();
  const award = await awardCheckInPoints(db, environment, {
    userId: user.id,
    activityId,
    checkInId,
    activityType: activity.type || "social_run",
    startsAt,
  });

  return {
    alreadyCheckedIn: false,
    pointsAwarded: award.pointsAwarded,
    bonusAwarded: award.bonusAwarded,
    message:
      award.bonusAwarded > 0
        ? `Asistencia registrada (+${award.pointsAwarded} pts, +${award.bonusAwarded} bonus).`
        : `Asistencia registrada (+${award.pointsAwarded} pts).`,
  };
}

async function syncConfirmedCount(db, environment, activityId) {
  const rsvps = collectionFor(db, environment, "activity_rsvps");
  const activities = collectionFor(db, environment, "activities");
  const snapshot = await rsvps
    .where("activityId", "==", activityId)
    .where("status", "==", "confirmed")
    .get();

  await activities.doc(activityId).update({
    confirmedCount: snapshot.size,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

module.exports = {
  assertValidEnvironment,
  requireAdmin,
  requireActiveUser,
  getPointsConfig,
  ecuadorIsoWeekKey,
  isCheckInWindowOpen,
  awardCheckInPoints,
  reverseCheckInPoints,
  performCheckIn,
  syncConfirmedCount,
  DEFAULT_CHECK_IN_POINTS,
  DEFAULT_WEEKLY_BONUS,
};

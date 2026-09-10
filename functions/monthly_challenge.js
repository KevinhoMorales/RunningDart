const { FieldValue } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");
const { collectionFor } = require("./firestore_helpers");
const {
  ecuadorIsoWeekKey,
  ecuadorMonthKey,
  leagueStandingId,
  getPointsConfig,
} = require("./activity_attendance");

const DEFAULT_CHALLENGE_COMPLETION_POINTS = 20;
const GOAL_TYPES = new Set([
  "check_ins",
  "weekly_social_runs",
  "tue_thu_weeks",
  "points",
]);

function progressDocId(challengeId, userId) {
  return `${challengeId}_${userId}`;
}

function badgeDocId(userId, challengeId) {
  return `${userId}_${challengeId}`;
}

function completionEventId(challengeId, userId) {
  return `challenge_complete_${challengeId}_${userId}`;
}

function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  return new Date(value);
}

function ecuadorWeekday(date) {
  // UTC-5: getUTCDay after shifting
  const ecuadorMs = date.getTime() - 5 * 60 * 60 * 1000;
  const ecuador = new Date(ecuadorMs);
  return ecuador.getUTCDay(); // 0=Sun … 6=Sat
}

async function listActiveChallenges(db, environment, now = new Date()) {
  const snap = await collectionFor(db, environment, "monthly_challenges")
    .where("status", "==", "active")
    .get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((c) => {
      const starts = toDate(c.startsAt);
      const ends = toDate(c.endsAt);
      if (!starts || !ends) return false;
      return now >= starts && now <= ends;
    });
}

async function loadUserCheckInsInRange(db, environment, userId, startsAt, endsAt) {
  const snap = await collectionFor(db, environment, "activity_checkins")
    .where("userId", "==", userId)
    .where("checkedInAt", ">=", startsAt)
    .where("checkedInAt", "<=", endsAt)
    .get();

  const rows = [];
  for (const doc of snap.docs) {
    const data = doc.data();
    rows.push({
      id: doc.id,
      activityId: data.activityId,
      checkedInAt: toDate(data.checkedInAt) || new Date(),
    });
  }

  const activityIds = [...new Set(rows.map((r) => r.activityId).filter(Boolean))];
  const activities = {};
  await Promise.all(
    activityIds.map(async (id) => {
      const snap = await collectionFor(db, environment, "activities")
        .doc(id)
        .get();
      if (snap.exists) {
        activities[id] = snap.data();
      }
    }),
  );

  return rows.map((row) => {
    const activity = activities[row.activityId] || {};
    const startsAt = toDate(activity.startsAt) || row.checkedInAt;
    return {
      ...row,
      activityType: activity.type || "social_run",
      activityStartsAt: startsAt,
      weekKey: ecuadorIsoWeekKey(startsAt),
      weekday: ecuadorWeekday(startsAt), // 2=Tue, 4=Thu
    };
  });
}

async function computeGoalProgress(db, environment, challenge, userId) {
  const target = Number(challenge.goalTarget) || 0;
  const goalType = challenge.goalType;
  const startsAt = toDate(challenge.startsAt);
  const endsAt = toDate(challenge.endsAt);
  if (!startsAt || !endsAt || target <= 0) {
    return { current: 0, target, completed: false };
  }

  if (goalType === "points") {
    const periodKey =
      typeof challenge.periodKey === "string" && challenge.periodKey
        ? challenge.periodKey
        : ecuadorMonthKey(startsAt);
    const standing = await collectionFor(db, environment, "league_standings")
      .doc(leagueStandingId(periodKey, userId))
      .get();
    const current = standing.exists ? standing.data().points || 0 : 0;
    return { current, target, completed: current >= target, periodKey };
  }

  const checkIns = await loadUserCheckInsInRange(
    db,
    environment,
    userId,
    startsAt,
    endsAt,
  );
  const social = checkIns.filter((c) => c.activityType === "social_run");

  if (goalType === "check_ins") {
    const current = checkIns.length;
    return { current, target, completed: current >= target };
  }

  if (goalType === "weekly_social_runs") {
    const weeks = new Set(social.map((c) => c.weekKey));
    const current = weeks.size;
    return { current, target, completed: current >= target };
  }

  if (goalType === "tue_thu_weeks") {
    const byWeek = new Map();
    for (const c of social) {
      const set = byWeek.get(c.weekKey) || new Set();
      if (c.weekday === 2) set.add("tue");
      if (c.weekday === 4) set.add("thu");
      byWeek.set(c.weekKey, set);
    }
    let current = 0;
    for (const set of byWeek.values()) {
      if (set.has("tue") && set.has("thu")) current += 1;
    }
    return { current, target, completed: current >= target };
  }

  return { current: 0, target, completed: false };
}

async function awardChallengeCompletion(db, environment, {
  challenge,
  userId,
  displayName,
  membershipModality,
}) {
  const completionPoints =
    typeof challenge.completionPoints === "number" &&
    challenge.completionPoints >= 0
      ? challenge.completionPoints
      : DEFAULT_CHALLENGE_COMPLETION_POINTS;

  const eventId = completionEventId(challenge.id, userId);
  const periodKey =
    typeof challenge.periodKey === "string" && challenge.periodKey
      ? challenge.periodKey
      : ecuadorMonthKey(toDate(challenge.startsAt) || new Date());

  let awardedPoints = 0;
  let newlyAwarded = false;

  if (completionPoints > 0) {
    await db.runTransaction(async (tx) => {
      const eventRef = collectionFor(db, environment, "point_events").doc(
        eventId,
      );
      const balanceRef = collectionFor(db, environment, "point_balances").doc(
        userId,
      );
      const standingRef = collectionFor(db, environment, "league_standings").doc(
        leagueStandingId(periodKey, userId),
      );

      const [existing, balanceSnap, standingSnap] = await Promise.all([
        tx.get(eventRef),
        tx.get(balanceRef),
        tx.get(standingRef),
      ]);

      if (existing.exists) {
        awardedPoints = existing.data().points || 0;
        return;
      }

      newlyAwarded = true;
      awardedPoints = completionPoints;
      const lifetime = balanceSnap.exists
        ? balanceSnap.data().totalPoints || 0
        : 0;
      const periodPoints = standingSnap.exists
        ? standingSnap.data().points || 0
        : 0;
      const name =
        typeof displayName === "string" && displayName.trim()
          ? displayName.trim()
          : "Miembro";

      tx.set(eventRef, {
        userId,
        type: "challenge_complete",
        points: awardedPoints,
        challengeId: challenge.id,
        periodKey,
        note: `Reto: ${challenge.name || challenge.id}`,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        balanceRef,
        {
          userId,
          totalPoints: lifetime + awardedPoints,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      tx.set(
        standingRef,
        {
          userId,
          periodKey,
          displayName: name,
          points: periodPoints + awardedPoints,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  }

  const badge = challenge.badge || {};
  const badgeRef = collectionFor(db, environment, "user_badges").doc(
    badgeDocId(userId, challenge.id),
  );
  await badgeRef.set(
    {
      userId,
      challengeId: challenge.id,
      periodKey,
      badgeName: badge.name || challenge.name || "Insignia SAINTS",
      badgeDescription: badge.description || challenge.description || null,
      iconName: badge.iconName || "emoji_events",
      colorHex: badge.colorHex || null,
      awardedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    newlyAwarded,
    awardedPoints,
    periodKey,
    membershipModality: membershipModality || null,
  };
}

/**
 * Recalcula progreso del usuario en retos activos.
 * Si completa, otorga badge + puntos (idempotente).
 */
async function syncChallengeProgressForUser(db, environment, {
  userId,
  displayName,
  membershipModality,
}) {
  const challenges = await listActiveChallenges(db, environment);
  const results = [];

  for (const challenge of challenges) {
    if (!GOAL_TYPES.has(challenge.goalType)) {
      continue;
    }

    const progress = await computeGoalProgress(
      db,
      environment,
      challenge,
      userId,
    );
    const progressRef = collectionFor(db, environment, "challenge_progress").doc(
      progressDocId(challenge.id, userId),
    );
    const existing = await progressRef.get();
    const wasCompleted = existing.exists && existing.data().completed === true;
    const name =
      typeof displayName === "string" && displayName.trim()
        ? displayName.trim()
        : existing.data()?.displayName || "Miembro";

    const payload = {
      challengeId: challenge.id,
      userId,
      displayName: name,
      periodKey:
        typeof challenge.periodKey === "string" && challenge.periodKey
          ? challenge.periodKey
          : ecuadorMonthKey(toDate(challenge.startsAt) || new Date()),
      goalType: challenge.goalType,
      goalTarget: progress.target,
      currentValue: progress.current,
      completed: progress.completed,
      membershipModality: membershipModality || null,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (progress.completed && !wasCompleted) {
      payload.completedAt = FieldValue.serverTimestamp();
      const award = await awardChallengeCompletion(db, environment, {
        challenge,
        userId,
        displayName: name,
        membershipModality,
      });
      payload.badgeAwarded = true;
      payload.pointsAwarded = award.awardedPoints > 0;
      payload.completionPointsAwarded = award.awardedPoints;
      results.push({
        challengeId: challenge.id,
        newlyCompleted: true,
        pointsAwarded: award.awardedPoints,
        current: progress.current,
        target: progress.target,
      });
    } else if (progress.completed && wasCompleted) {
      payload.badgeAwarded = true;
      payload.pointsAwarded = existing.data().pointsAwarded === true;
      results.push({
        challengeId: challenge.id,
        newlyCompleted: false,
        pointsAwarded: 0,
        current: progress.current,
        target: progress.target,
      });
    } else {
      payload.badgeAwarded = false;
      payload.pointsAwarded = false;
      results.push({
        challengeId: challenge.id,
        newlyCompleted: false,
        pointsAwarded: 0,
        current: progress.current,
        target: progress.target,
      });
    }

    // No pisar isWinner / qualifiesForOfficialPerk al sincronizar progreso.
    await progressRef.set(payload, { merge: true });
  }

  return results;
}

async function adminSetChallengeWinners(db, environment, {
  adminUid,
  challengeId,
  winnerUserIds,
}) {
  if (typeof challengeId !== "string" || !challengeId) {
    throw new HttpsError("invalid-argument", "Falta el reto.");
  }
  if (!Array.isArray(winnerUserIds)) {
    throw new HttpsError("invalid-argument", "Lista de ganadores inválida.");
  }

  const challengeSnap = await collectionFor(db, environment, "monthly_challenges")
    .doc(challengeId)
    .get();
  if (!challengeSnap.exists) {
    throw new HttpsError("not-found", "Reto no encontrado.");
  }
  const challenge = { id: challengeSnap.id, ...challengeSnap.data() };
  const spots = Number(challenge.rewardSpots) || 0;
  if (winnerUserIds.length > spots) {
    throw new HttpsError(
      "failed-precondition",
      `Solo hay ${spots} Reward Spots.`,
    );
  }

  const unique = [...new Set(winnerUserIds.filter((id) => typeof id === "string"))];
  const progressCol = collectionFor(db, environment, "challenge_progress");
  const finishersSnap = await progressCol
    .where("challengeId", "==", challengeId)
    .where("completed", "==", true)
    .get();

  const finisherIds = new Set(finishersSnap.docs.map((d) => d.data().userId));
  for (const uid of unique) {
    if (!finisherIds.has(uid)) {
      throw new HttpsError(
        "failed-precondition",
        "Solo pueden ganar quienes completaron el reto.",
      );
    }
  }

  // Clear previous winners then set new ranks.
  // Order of `unique` = League rank among finishers (client sorts by points).
  // Official status only adds qualifiesForOfficialPerk — never reorders.
  const batch = db.batch();
  const perkLabel =
    typeof challenge.officialPerkLabel === "string" &&
    challenge.officialPerkLabel.trim()
      ? challenge.officialPerkLabel.trim()
      : null;
  const perkDescription =
    typeof challenge.officialPerkDescription === "string" &&
    challenge.officialPerkDescription.trim()
      ? challenge.officialPerkDescription.trim()
      : null;

  for (const doc of finishersSnap.docs) {
    const data = doc.data();
    const isWinner = unique.includes(data.userId);
    const rank = isWinner ? unique.indexOf(data.userId) + 1 : null;
    let qualifies = false;
    let modality = data.membershipModality || null;
    if (isWinner) {
      const userSnap = await collectionFor(db, environment, "users")
        .doc(data.userId)
        .get();
      const userData = userSnap.exists ? userSnap.data() || {} : {};
      modality = userData.membershipModality || modality;
      // Legacy proTeam maps to official on client; treat both as Official.
      const isOfficialModality =
        modality === "official" || modality === "proTeam";
      const status = userData.membershipStatus || "active";
      let expired = false;
      if (userData.expiresAt && typeof userData.expiresAt.toDate === "function") {
        expired = userData.expiresAt.toDate().getTime() < Date.now();
      } else if (userData.expiresAt instanceof Date) {
        expired = userData.expiresAt.getTime() < Date.now();
      }
      // Active Official only — membership never changes ranking, only perk.
      qualifies =
        isOfficialModality && status === "active" && !expired;
    }
    batch.set(
      doc.ref,
      {
        isWinner,
        winnerRank: rank,
        qualifiesForOfficialPerk: qualifies,
        membershipModality: modality || null,
        officialPerkLabel: isWinner && qualifies ? perkLabel : null,
        officialPerkDescription:
          isWinner && qualifies ? perkDescription : null,
        winnerMarkedAt: isWinner ? FieldValue.serverTimestamp() : null,
        winnerMarkedBy: isWinner ? adminUid : null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();

  await collectionFor(db, environment, "monthly_challenges").doc(challengeId).set(
    {
      winnersCount: unique.length,
      winnersUpdatedAt: FieldValue.serverTimestamp(),
      winnersUpdatedBy: adminUid,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { success: true, winnersCount: unique.length, rewardSpots: spots };
}

module.exports = {
  DEFAULT_CHALLENGE_COMPLETION_POINTS,
  GOAL_TYPES,
  progressDocId,
  badgeDocId,
  completionEventId,
  listActiveChallenges,
  computeGoalProgress,
  syncChallengeProgressForUser,
  adminSetChallengeWinners,
  awardChallengeCompletion,
};

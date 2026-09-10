const { getMessaging } = require("firebase-admin/messaging");
const { FieldValue } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const { collectionFor } = require("./firestore_helpers");

const ANDROID_CHANNEL_ID = "saints_alerts";

/**
 * Env-scoped topics (same pattern as businesses / news).
 * Targeted attendance / challenge pushes use user `fcmTokens` arrays instead.
 */
const topicNewBusinesses = (environment) =>
  `saints_new_businesses_${environment}`;
const topicNewEvents = (environment) => `saints_new_events_${environment}`;
const topicClubActivities = (environment) =>
  `saints_club_activities_${environment}`;

async function sendTopicNotification({ topic, title, body, data }) {
  const payloadData = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value == null) continue;
    payloadData[key] = String(value);
  }

  await getMessaging().send({
    topic,
    notification: { title, body },
    data: payloadData,
    android: {
      priority: "high",
      notification: { channelId: ANDROID_CHANNEL_ID },
    },
    apns: {
      payload: {
        aps: { sound: "default" },
      },
    },
  });
}

function tokensFromUserData(data) {
  if (!data || typeof data !== "object") return [];
  const raw = data.fcmTokens;
  if (!Array.isArray(raw)) return [];
  return [
    ...new Set(
      raw.filter((t) => typeof t === "string" && t.trim().length > 0),
    ),
  ];
}

async function collectTokensForUserIds(db, environment, userIds) {
  const unique = [...new Set(userIds.filter((id) => typeof id === "string"))];
  const tokens = [];
  const users = collectionFor(db, environment, "users");

  // Firestore getAll batches of 100.
  for (let i = 0; i < unique.length; i += 100) {
    const chunk = unique.slice(i, i + 100);
    const refs = chunk.map((id) => users.doc(id));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      if (!snap.exists) continue;
      tokens.push(...tokensFromUserData(snap.data()));
    }
  }
  return [...new Set(tokens)];
}

async function sendToTokens({ tokens, title, body, data }) {
  const unique = [...new Set((tokens || []).filter(Boolean))];
  if (unique.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  const payloadData = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value == null) continue;
    payloadData[key] = String(value);
  }

  const messaging = getMessaging();
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < unique.length; i += 500) {
    const chunk = unique.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: payloadData,
      android: {
        priority: "high",
        notification: { channelId: ANDROID_CHANNEL_ID },
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
  }

  return { successCount, failureCount };
}

async function sendToUserIds(db, environment, userIds, { title, body, data }) {
  const tokens = await collectTokensForUserIds(db, environment, userIds);
  return sendToTokens({ tokens, title, body, data });
}

async function listConfirmedAttendeeIds(db, environment, activityId) {
  const snap = await collectionFor(db, environment, "activity_rsvps")
    .where("activityId", "==", activityId)
    .where("status", "==", "confirmed")
    .get();
  return snap.docs
    .map((d) => d.data().userId)
    .filter((id) => typeof id === "string" && id.length > 0);
}

async function notifyCheckInOpened(db, environment, activity) {
  const activityId = activity.id;
  const title = "Check-in abierto";
  const name =
    typeof activity.title === "string" && activity.title.trim()
      ? activity.title.trim()
      : "la actividad";
  const body = `Ya puedes registrar asistencia en ${name}.`;
  const userIds = await listConfirmedAttendeeIds(db, environment, activityId);
  if (userIds.length === 0) {
    logger.info("check-in open: no confirmed attendees", {
      environment,
      activityId,
    });
    return { sent: 0 };
  }
  const result = await sendToUserIds(db, environment, userIds, {
    title,
    body,
    data: {
      type: "activity_checkin",
      id: activityId,
    },
  });
  logger.info("check-in open notified", {
    environment,
    activityId,
    attendees: userIds.length,
    ...result,
  });
  return { sent: result.successCount, attendees: userIds.length };
}

async function notifyUpcomingActivity(db, environment, activity) {
  const activityId = activity.id;
  const name =
    typeof activity.title === "string" && activity.title.trim()
      ? activity.title.trim()
      : "Social Run";
  const title = "Próxima actividad";
  const body = `${name} empieza pronto. Confirma y llega listo.`;
  const userIds = await listConfirmedAttendeeIds(db, environment, activityId);
  if (userIds.length === 0) {
    return { sent: 0, skipped: "no_attendees" };
  }
  const result = await sendToUserIds(db, environment, userIds, {
    title,
    body,
    data: {
      type: "activity",
      id: activityId,
    },
  });
  await collectionFor(db, environment, "activities").doc(activityId).set(
    {
      reminderNotifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  logger.info("activity reminder notified", {
    environment,
    activityId,
    attendees: userIds.length,
    ...result,
  });
  return { sent: result.successCount, attendees: userIds.length };
}

/**
 * Reminder window: activities starting in ~75–105 minutes (15-min cron ≈ 90 min ahead).
 */
async function sendUpcomingActivityRemindersForEnvironment(db, environment) {
  const now = Date.now();
  const windowStart = new Date(now + 75 * 60 * 1000);
  const windowEnd = new Date(now + 105 * 60 * 1000);

  const snap = await collectionFor(db, environment, "activities")
    .where("isPublished", "==", true)
    .where("startsAt", ">=", windowStart)
    .where("startsAt", "<=", windowEnd)
    .get();

  let notified = 0;
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (data.reminderNotifiedAt) continue;
    const result = await notifyUpcomingActivity(db, environment, {
      id: doc.id,
      ...data,
    });
    if (result.sent > 0 || result.attendees > 0) {
      notified += 1;
    } else if (result.skipped === "no_attendees") {
      // Mark so we don't retry empty RSVP forever in this window.
      await doc.ref.set(
        {
          reminderNotifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  }
  return { environment, candidates: snap.size, notified };
}

async function notifyChallengeCompleted(db, environment, {
  userId,
  challengeId,
  challengeName,
  badgeName,
  pointsAwarded,
}) {
  const name =
    (typeof badgeName === "string" && badgeName.trim()) ||
    (typeof challengeName === "string" && challengeName.trim()) ||
    "el reto del mes";
  const title = "Reto completado";
  const points =
    typeof pointsAwarded === "number" && pointsAwarded > 0
      ? ` (+${pointsAwarded} pts)`
      : "";
  const body = `Desbloqueaste la insignia ${name}${points}.`;
  return sendToUserIds(db, environment, [userId], {
    title,
    body,
    data: {
      type: "challenge",
      id: challengeId || "league",
    },
  });
}

async function notifyChallengeWinners(db, environment, {
  challengeId,
  challengeName,
  winners,
}) {
  // winners: [{ userId, qualifiesForOfficialPerk, officialPerkLabel }]
  let sent = 0;
  for (const winner of winners || []) {
    if (!winner?.userId) continue;
    const challengeLabel =
      typeof challengeName === "string" && challengeName.trim()
        ? challengeName.trim()
        : "el reto del mes";
    if (winner.qualifiesForOfficialPerk) {
      const perk =
        typeof winner.officialPerkLabel === "string" &&
        winner.officialPerkLabel.trim()
          ? winner.officialPerkLabel.trim()
          : "perk Oficial";
      await sendToUserIds(db, environment, [winner.userId], {
        title: "Reward Spot + perk Oficial",
        body: `Ganaste el premio de ${challengeLabel} y tu perk: ${perk}.`,
        data: {
          type: "challenge",
          id: challengeId || "league",
        },
      });
    } else {
      await sendToUserIds(db, environment, [winner.userId], {
        title: "Ganaste un Reward Spot",
        body: `Premio general de ${challengeLabel}. ¡Felicitaciones!`,
        data: {
          type: "challenge",
          id: challengeId || "league",
        },
      });
    }
    sent += 1;
  }
  return { sent };
}

module.exports = {
  ANDROID_CHANNEL_ID,
  topicNewBusinesses,
  topicNewEvents,
  topicClubActivities,
  sendTopicNotification,
  tokensFromUserData,
  collectTokensForUserIds,
  sendToTokens,
  sendToUserIds,
  listConfirmedAttendeeIds,
  notifyCheckInOpened,
  notifyUpcomingActivity,
  sendUpcomingActivityRemindersForEnvironment,
  notifyChallengeCompleted,
  notifyChallengeWinners,
};

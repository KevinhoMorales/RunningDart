const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

const { deleteEnvironmentAccountData } = require("./account_deletion");
const { deletePostLikes, syncPostLikeSummary } = require("./post_likes");
const {
  deletePostComments,
  syncPostCommentCount,
} = require("./post_comments");
const {
  assertValidEnvironment,
  requireAdmin,
  requireActiveUser,
  performCheckIn,
  reverseCheckInPoints,
  syncConfirmedCount,
} = require("./activity_attendance");
const {
  syncChallengeProgressForUser,
  adminSetChallengeWinners,
} = require("./monthly_challenge");
const { collectionFor } = require("./firestore_helpers");
const { FieldValue } = require("firebase-admin/firestore");
const {
  topicNewBusinesses,
  topicNewEvents,
  sendTopicNotification,
  notifyCheckInOpened,
  notifyChallengeCompleted,
  notifyChallengeWinners,
  sendUpcomingActivityRemindersForEnvironment,
} = require("./push_notifications");

initializeApp();

async function notifyIfChallengeCompleted(db, environment, userId, newly) {
  if (!newly?.newlyCompleted) return;
  try {
    await notifyChallengeCompleted(db, environment, {
      userId,
      challengeId: newly.challengeId,
      challengeName: newly.challengeName,
      badgeName: newly.badgeName,
      pointsAwarded: newly.pointsAwarded,
    });
  } catch (error) {
    logger.warn("Challenge complete push failed", {
      environment,
      userId,
      message: error?.message,
    });
  }
}

async function attachChallengeProgress(db, environment, result, user) {
  if (!result || result.alreadyCheckedIn) {
    return result;
  }
  try {
    const challengeResults = await syncChallengeProgressForUser(
      db,
      environment,
      {
        userId: user.id,
        displayName:
          result.displayName ||
          user.displayName ||
          user.display_name ||
          "Miembro",
        membershipModality:
          result.membershipModality || user.membershipModality || null,
      },
    );
    const newly = challengeResults.find((r) => r.newlyCompleted);
    if (newly) {
      result.challengeCompleted = true;
      result.challengePointsAwarded = newly.pointsAwarded || 0;
      if (newly.pointsAwarded > 0) {
        result.message = `${result.message} · Reto completado (+${newly.pointsAwarded} pts).`;
      } else {
        result.message = `${result.message} · Reto completado · insignia desbloqueada.`;
      }
      await notifyIfChallengeCompleted(db, environment, user.id, newly);
    }
  } catch (error) {
    logger.warn("Challenge progress sync failed", {
      environment,
      userId: user.id,
      message: error?.message,
    });
  }
  return result;
}

const VALID_ENVIRONMENTS = new Set(["dev", "prod"]);

exports.onBusinessCreated = onDocumentCreated(
  "environments/{environment}/businesses/{businessId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const data = event.data?.data();
    if (!data) {
      return;
    }

    const businessId = event.params.businessId;
    const name = typeof data.name === "string" ? data.name.trim() : "";

    await sendTopicNotification({
      topic: topicNewBusinesses(environment),
      title: "Nueva marca aliada",
      body: name || "Hay una nueva marca aliada en SAINTS",
      data: { type: "business", id: businessId },
    });
  },
);

exports.onNewsCreated = onDocumentCreated(
  "environments/{environment}/news/{newsId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const data = event.data?.data();
    if (!data || data.isPublished !== true) {
      return;
    }

    const newsId = event.params.newsId;
    const title = typeof data.title === "string" ? data.title.trim() : "";

    await sendTopicNotification({
      topic: topicNewEvents(environment),
      title: "Nuevo evento",
      body: title || "Hay un nuevo evento en SAINTS",
      data: { type: "news", id: newsId },
    });
  },
);

exports.onNewsPublished = onDocumentUpdated(
  "environments/{environment}/news/{newsId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) {
      return;
    }

    if (before.isPublished === true || after.isPublished !== true) {
      return;
    }

    const newsId = event.params.newsId;
    const title = typeof after.title === "string" ? after.title.trim() : "";

    await sendTopicNotification({
      topic: topicNewEvents(environment),
      title: "Nuevo evento",
      body: title || "Hay un nuevo evento en SAINTS",
      data: { type: "news", id: newsId },
    });
  },
);

/** Check-in window opened by admin → push to confirmed attendees. */
exports.onActivityCheckInEnabled = onDocumentUpdated(
  "environments/{environment}/activities/{activityId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    if (before.checkInEnabled === true || after.checkInEnabled !== true) {
      return;
    }

    const activityId = event.params.activityId;
    try {
      await notifyCheckInOpened(getFirestore(), environment, {
        id: activityId,
        ...after,
      });
    } catch (error) {
      logger.warn("check-in open push failed", {
        environment,
        activityId,
        message: error?.message,
      });
    }
  },
);

exports.onPostLikeWritten = onDocumentWritten(
  "environments/{environment}/post_likes/{likeId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const after = event.data?.after?.data();
    const before = event.data?.before?.data();
    const postId = after?.postId ?? before?.postId;

    if (typeof postId !== "string" || postId.length === 0) {
      return;
    }

    await syncPostLikeSummary(getFirestore(), environment, postId);
  },
);

exports.onPostCommentWritten = onDocumentWritten(
  "environments/{environment}/post_comments/{commentId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const after = event.data?.after?.data();
    const before = event.data?.before?.data();
    const postId = after?.postId ?? before?.postId;

    if (typeof postId !== "string" || postId.length === 0) {
      return;
    }

    await syncPostCommentCount(getFirestore(), environment, postId);
  },
);

exports.onPostDeleted = onDocumentDeleted(
  "environments/{environment}/posts/{postId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const db = getFirestore();
    const postId = event.params.postId;
    await Promise.all([
      deletePostLikes(db, environment, postId),
      deletePostComments(db, environment, postId),
    ]);
  },
);

exports.onActivityRsvpWritten = onDocumentWritten(
  "environments/{environment}/activity_rsvps/{rsvpId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    const after = event.data?.after?.data();
    const before = event.data?.before?.data();
    const activityId = after?.activityId ?? before?.activityId;
    if (typeof activityId !== "string" || activityId.length === 0) {
      return;
    }

    await syncConfirmedCount(getFirestore(), environment, activityId);
  },
);

exports.checkInToActivity = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para hacer check-in.",
    );
  }

  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);

  const activityId = request.data?.activityId;
  const token = request.data?.token;
  if (typeof activityId !== "string" || activityId.length === 0) {
    throw new HttpsError("invalid-argument", "Falta la actividad.");
  }
  if (typeof token !== "string" || token.length === 0) {
    throw new HttpsError("invalid-argument", "Falta el token del QR.");
  }

  const db = getFirestore();
  const user = await requireActiveUser(db, environment, request.auth.uid);
  const result = await performCheckIn(db, environment, {
    activityId,
    user,
    method: "qr",
    token,
    skipWindowCheck: false,
  });
  return attachChallengeProgress(db, environment, result, user);
});

exports.adminMarkActivityCheckIn = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);

  const activityId = request.data?.activityId;
  const userId = request.data?.userId;
  if (typeof activityId !== "string" || activityId.length === 0) {
    throw new HttpsError("invalid-argument", "Falta la actividad.");
  }
  if (typeof userId !== "string" || userId.length === 0) {
    throw new HttpsError("invalid-argument", "Falta el usuario.");
  }

  const db = getFirestore();
  await requireAdmin(db, environment, request.auth.uid);
  const user = await requireActiveUser(db, environment, userId);

  const result = await performCheckIn(db, environment, {
    activityId,
    user,
    method: "admin",
    checkedInBy: request.auth.uid,
    skipWindowCheck: true,
  });
  return attachChallengeProgress(db, environment, result, user);
});

exports.adminRemoveActivityCheckIn = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);

  const activityId = request.data?.activityId;
  const userId = request.data?.userId;
  if (typeof activityId !== "string" || activityId.length === 0) {
    throw new HttpsError("invalid-argument", "Falta la actividad.");
  }
  if (typeof userId !== "string" || userId.length === 0) {
    throw new HttpsError("invalid-argument", "Falta el usuario.");
  }

  const db = getFirestore();
  await requireAdmin(db, environment, request.auth.uid);

  const checkInId = `${activityId}_${userId}`;
  const checkInRef = collectionFor(db, environment, "activity_checkins").doc(
    checkInId,
  );
  const activityRef = collectionFor(db, environment, "activities").doc(
    activityId,
  );
  const snap = await checkInRef.get();
  if (!snap.exists) {
    return { success: true, removed: false };
  }

  const data = snap.data();
  await reverseCheckInPoints(db, environment, {
    userId,
    checkInId,
    checkInEventId: data.pointEventId || `checkin_${checkInId}`,
  });

  await db.runTransaction(async (tx) => {
    const again = await tx.get(checkInRef);
    if (!again.exists) {
      return;
    }
    tx.delete(checkInRef);
    tx.update(activityRef, {
      checkedInCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true, removed: true };
});

exports.evaluateMyChallengeProgress = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);
  const db = getFirestore();
  const user = await requireActiveUser(db, environment, request.auth.uid);
  const results = await syncChallengeProgressForUser(db, environment, {
    userId: user.id,
    displayName: user.displayName || user.display_name || "Miembro",
    membershipModality: user.membershipModality || null,
  });
  for (const newly of results.filter((r) => r.newlyCompleted)) {
    await notifyIfChallengeCompleted(db, environment, user.id, newly);
  }
  return { success: true, results };
});

exports.adminSetChallengeWinners = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);
  const db = getFirestore();
  await requireAdmin(db, environment, request.auth.uid);
  const result = await adminSetChallengeWinners(db, environment, {
    adminUid: request.auth.uid,
    challengeId: request.data?.challengeId,
    winnerUserIds: request.data?.winnerUserIds,
  });
  try {
    if (result.newlyWon && result.newlyWon.length > 0) {
      await notifyChallengeWinners(db, environment, {
        challengeId: request.data?.challengeId,
        challengeName: result.challengeName,
        winners: result.newlyWon,
      });
    }
  } catch (error) {
    logger.warn("Challenge winners push failed", {
      environment,
      message: error?.message,
    });
  }
  return result;
});

/**
 * ~90 min before start: remind confirmed attendees.
 * Requires Cloud Scheduler (Blaze). Deploy with functions.
 * Manual backfill: adminSendActivityReminders callable.
 */
exports.sendUpcomingActivityReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "America/Guayaquil",
  },
  async () => {
    const db = getFirestore();
    const outcomes = [];
    for (const environment of VALID_ENVIRONMENTS) {
      try {
        outcomes.push(
          await sendUpcomingActivityRemindersForEnvironment(db, environment),
        );
      } catch (error) {
        logger.warn("activity reminder sweep failed", {
          environment,
          message: error?.message,
        });
        outcomes.push({ environment, error: error?.message });
      }
    }
    logger.info("activity reminder sweep", { outcomes });
  },
);

exports.adminSendActivityReminders = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const environment =
    request.data?.environment === "dev" ? "dev" : "prod";
  assertValidEnvironment(environment);
  const db = getFirestore();
  await requireAdmin(db, environment, request.auth.uid);
  return sendUpcomingActivityRemindersForEnvironment(db, environment);
});

exports.deleteMyAccount = onCall({ timeoutSeconds: 540 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para eliminar tu cuenta.",
    );
  }

  const uid = request.auth.uid;
  const environment = request.data?.environment === "dev" ? "dev" : "prod";
  const db = getFirestore();
  const bucket = getStorage().bucket();

  const deleted = await deleteEnvironmentAccountData(
    db,
    bucket,
    environment,
    uid,
  );

  logger.info("deleteMyAccount completed", { uid, environment, deleted });

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw new HttpsError(
        "internal",
        "No se pudo eliminar la cuenta. Intenta de nuevo.",
      );
    }
  }

  return { success: true, environment, deleted };
});

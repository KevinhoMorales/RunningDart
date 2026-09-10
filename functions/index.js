const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

initializeApp();

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

// El topic lleva sufijo de ambiente para que una marca o noticia de prueba en
// dev no dispare un push a todos los usuarios de producción.
const topicNewBusinesses = (environment) =>
  `saints_new_businesses_${environment}`;
const topicNewEvents = (environment) => `saints_new_events_${environment}`;
const VALID_ENVIRONMENTS = new Set(["dev", "prod"]);

async function sendTopicNotification({ topic, title, body, type, id }) {
  await getMessaging().send({
    topic,
    notification: {
      title,
      body,
    },
    data: {
      type,
      id,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "saints_alerts",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });
}

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
      type: "business",
      id: businessId,
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
      type: "news",
      id: newsId,
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
      type: "news",
      id: newsId,
    });
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
  return adminSetChallengeWinners(db, environment, {
    adminUid: request.auth.uid,
    challengeId: request.data?.challengeId,
    winnerUserIds: request.data?.winnerUserIds,
  });
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

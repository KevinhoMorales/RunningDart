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

initializeApp();

const TOPIC_NEW_BUSINESSES = "saints_new_businesses";
const TOPIC_NEW_EVENTS = "saints_new_events";
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
      topic: TOPIC_NEW_BUSINESSES,
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
      topic: TOPIC_NEW_EVENTS,
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
      topic: TOPIC_NEW_EVENTS,
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

exports.onPostDeleted = onDocumentDeleted(
  "environments/{environment}/posts/{postId}",
  async (event) => {
    const environment = event.params.environment;
    if (!VALID_ENVIRONMENTS.has(environment)) {
      return;
    }

    await deletePostLikes(getFirestore(), environment, event.params.postId);
  },
);

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

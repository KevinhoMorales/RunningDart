const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

const TOPIC_NEW_BUSINESSES = "saints_new_businesses";
const TOPIC_NEW_EVENTS = "saints_new_events";

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
  "businesses/{businessId}",
  async (event) => {
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

exports.onNewsCreated = onDocumentCreated("news/{newsId}", async (event) => {
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
});

exports.onNewsPublished = onDocumentUpdated("news/{newsId}", async (event) => {
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
});

async function deleteStoragePrefix(bucket, prefix) {
  const [files] = await bucket.getFiles({ prefix });
  await Promise.all(
    files.map((file) =>
      file.delete().catch(() => undefined),
    ),
  );
}

exports.deleteMyAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión para eliminar tu cuenta.",
    );
  }

  const uid = request.auth.uid;
  const db = getFirestore();
  const bucket = getStorage().bucket();

  const paymentsSnapshot = await db
    .collection("payments")
    .where("userId", "==", uid)
    .get();

  await Promise.all(
    paymentsSnapshot.docs.map((doc) => doc.ref.delete()),
  );

  await deleteStoragePrefix(bucket, `payments/${uid}/`);
  await bucket
    .file(`users/${uid}/profile.jpg`)
    .delete()
    .catch(() => undefined);

  await db.collection("users").doc(uid).delete();

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

  return { success: true };
});

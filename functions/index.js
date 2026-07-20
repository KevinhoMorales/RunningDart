const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

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
      title: "Nuevo negocio",
      body: name || "Hay un nuevo negocio en SAINTS",
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

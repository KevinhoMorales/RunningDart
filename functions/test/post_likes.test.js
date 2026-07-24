const assert = require("node:assert/strict");
const { after, before, describe, it } = require("node:test");

const { initializeApp, deleteApp } = require("firebase-admin/app");
const { Timestamp, getFirestore } = require("firebase-admin/firestore");

const { collectionFor } = require("../firestore_helpers");
const { deletePostLikes, syncPostLikeSummary } = require("../post_likes");

// Estas pruebas necesitan el emulador de Firestore:
//   firebase emulators:start --only firestore --project demo-saints
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
const ENVIRONMENT = "dev";
const POST_ID = "post-1";

describe("post likes summary", { skip: !EMULATOR }, () => {
  let app;
  let db;

  before(() => {
    app = initializeApp({ projectId: "demo-saints" }, "post-likes-test");
    db = getFirestore(app);
  });

  after(async () => {
    await deleteApp(app);
  });

  const collection = (name) => collectionFor(db, ENVIRONMENT, name);

  async function wipe() {
    for (const name of ["posts", "post_likes", "public_profiles"]) {
      const snapshot = await collection(name).get();
      await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
    }
  }

  // Los likes se numeran para controlar el orden: el 4 es el más reciente.
  async function seedLikes(count) {
    const batch = db.batch();
    batch.set(collection("posts").doc(POST_ID), { authorId: "author" });

    for (let i = 1; i <= count; i++) {
      const userId = `user-${i}`;
      batch.set(collection("public_profiles").doc(userId), {
        displayName: `Usuario ${i}`,
        photoUrl: `https://example.com/${i}.jpg`,
      });
      batch.set(collection("post_likes").doc(`${POST_ID}_${userId}`), {
        postId: POST_ID,
        userId,
        postAuthorId: "author",
        createdAt: Timestamp.fromMillis(1000 + i),
      });
    }

    await batch.commit();
  }

  it("counts every like and keeps the three most recent names", async () => {
    await wipe();
    await seedLikes(4);

    const summary = await syncPostLikeSummary(db, ENVIRONMENT, POST_ID);

    assert.equal(summary.likesCount, 4);
    assert.deepEqual(
      summary.recentLikes.map((like) => like.userId),
      ["user-4", "user-3", "user-2"],
    );

    const post = (await collection("posts").doc(POST_ID).get()).data();
    assert.equal(post.likesCount, 4);
    assert.equal(post.recentLikes[0].displayName, "Usuario 4");
    assert.equal(post.recentLikes[0].photoUrl, "https://example.com/4.jpg");
    assert.equal(post.authorId, "author");
  });

  it("falls back to a generic name when there is no public profile",
    async () => {
      await wipe();
      await collection("posts").doc(POST_ID).set({ authorId: "author" });
      await collection("post_likes").doc(`${POST_ID}_ghost`).set({
        postId: POST_ID,
        userId: "ghost",
        postAuthorId: "author",
        createdAt: Timestamp.fromMillis(1000),
      });

      const summary = await syncPostLikeSummary(db, ENVIRONMENT, POST_ID);

      assert.equal(summary.likesCount, 1);
      assert.equal(summary.recentLikes[0].displayName, "Miembro SAINTS");
      assert.equal(summary.recentLikes[0].photoUrl, undefined);
    });

  it("leaves the counter at zero once the likes are gone", async () => {
    await wipe();
    await seedLikes(2);

    const removed = await deletePostLikes(db, ENVIRONMENT, POST_ID);
    assert.equal(removed, 2);

    const summary = await syncPostLikeSummary(db, ENVIRONMENT, POST_ID);
    assert.equal(summary.likesCount, 0);
    assert.deepEqual(summary.recentLikes, []);
  });

  it("does nothing when the post no longer exists", async () => {
    await wipe();

    const summary = await syncPostLikeSummary(db, ENVIRONMENT, "missing-post");

    assert.equal(summary, null);
  });
});

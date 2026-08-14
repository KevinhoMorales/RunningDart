const assert = require("node:assert/strict");
const { after, before, describe, it } = require("node:test");

const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const { collectionFor } = require("../firestore_helpers");
const {
  deletePostComments,
  syncPostCommentCount,
} = require("../post_comments");

// Estas pruebas necesitan el emulador de Firestore:
//   firebase emulators:start --only firestore --project demo-saints
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
const ENVIRONMENT = "dev";
const POST_ID = "post-comments-1";

describe("post comments count", { skip: !EMULATOR }, () => {
  let app;
  let db;

  before(() => {
    app = initializeApp({ projectId: "demo-saints" }, "post-comments-test");
    db = getFirestore(app);
  });

  after(async () => {
    await deleteApp(app);
  });

  const collection = (name) => collectionFor(db, ENVIRONMENT, name);

  async function wipe() {
    for (const name of ["posts", "post_comments"]) {
      const snapshot = await collection(name).get();
      await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
    }
  }

  it("recounts comments on a post", async () => {
    await wipe();
    await collection("posts").doc(POST_ID).set({
      authorId: "author-1",
      authorName: "Autor",
      createdAt: new Date(),
      isHidden: false,
      likesCount: 0,
      commentsCount: 0,
    });

    const batch = db.batch();
    for (let i = 0; i < 3; i += 1) {
      batch.set(collection("post_comments").doc(`c-${i}`), {
        postId: POST_ID,
        postAuthorId: "author-1",
        authorId: `user-${i}`,
        authorName: `Usuario ${i}`,
        text: `Hola ${i}`,
        createdAt: new Date(Date.now() + i * 1000),
      });
    }
    await batch.commit();

    const summary = await syncPostCommentCount(db, ENVIRONMENT, POST_ID);
    assert.equal(summary.commentsCount, 3);

    const post = (await collection("posts").doc(POST_ID).get()).data();
    assert.equal(post.commentsCount, 3);
  });

  it("deletes every comment of a post", async () => {
    await wipe();
    await collection("post_comments").doc("c-1").set({
      postId: POST_ID,
      postAuthorId: "author-1",
      authorId: "user-1",
      authorName: "Ana",
      text: "Hola",
      createdAt: new Date(),
    });
    await collection("post_comments").doc("c-other").set({
      postId: "other-post",
      postAuthorId: "author-2",
      authorId: "user-1",
      authorName: "Ana",
      text: "Otro",
      createdAt: new Date(),
    });

    const deleted = await deletePostComments(db, ENVIRONMENT, POST_ID);
    assert.equal(deleted, 1);
    assert.equal(
      (await collection("post_comments").doc("c-1").get()).exists,
      false,
    );
    assert.equal(
      (await collection("post_comments").doc("c-other").get()).exists,
      true,
    );
  });
});

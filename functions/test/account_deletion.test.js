const assert = require("node:assert/strict");
const { after, before, describe, it } = require("node:test");

const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const {
  DELETED_MEMBER_NAME,
  DELETED_USER_SENTINEL,
  collectionFor,
  deleteEnvironmentAccountData,
} = require("../account_deletion");

// Estas pruebas necesitan el emulador de Firestore:
//   firebase emulators:start --only firestore --project demo-saints
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
const ENVIRONMENT = "dev";
const UID = "user-to-delete";
const OTHER_UID = "someone-else";

// Doble de Storage: aquí solo interesa que la cascada pida borrar los prefijos
// correctos, no ejercitar el bucket real.
function fakeBucket() {
  const deletedPrefixes = [];
  return {
    deletedPrefixes,
    async getFiles({ prefix }) {
      deletedPrefixes.push(prefix);
      return [[]];
    },
  };
}

describe("deleteEnvironmentAccountData", { skip: !EMULATOR }, () => {
  let app;
  let db;

  before(() => {
    app = initializeApp({ projectId: "demo-saints" }, "account-deletion-test");
    db = getFirestore(app);
  });

  after(async () => {
    await deleteApp(app);
  });

  const collection = (name) => collectionFor(db, ENVIRONMENT, name);

  async function seed() {
    const batch = db.batch();

    batch.set(collection("users").doc(UID), {
      email: "delete@test.com",
      displayName: "Delete Me",
      username: "deleteme",
    });
    batch.set(collection("public_profiles").doc(UID), {
      displayName: "Delete Me",
    });
    batch.set(collection("usernames").doc("deleteme"), { userId: UID });

    batch.set(collection("posts").doc("post-1"), { authorId: UID });
    batch.set(collection("posts").doc("post-2"), { authorId: UID });
    batch.set(collection("posts").doc("post-other"), { authorId: OTHER_UID });

    batch.set(collection("follows").doc(`${UID}_${OTHER_UID}`), {
      followerId: UID,
      followedId: OTHER_UID,
    });
    batch.set(collection("follows").doc(`${OTHER_UID}_${UID}`), {
      followerId: OTHER_UID,
      followedId: UID,
    });

    batch.set(collection("blocks").doc(`${UID}_${OTHER_UID}`), {
      blockerId: UID,
      blockedId: OTHER_UID,
    });
    batch.set(collection("blocks").doc(`${OTHER_UID}_${UID}`), {
      blockerId: OTHER_UID,
      blockedId: UID,
    });

    batch.set(collection("post_likes").doc(`post-other_${UID}`), {
      postId: "post-other",
      userId: UID,
      postAuthorId: OTHER_UID,
    });
    batch.set(collection("post_likes").doc(`post-1_${OTHER_UID}`), {
      postId: "post-1",
      userId: OTHER_UID,
      postAuthorId: UID,
    });

    batch.set(collection("post_comments").doc("comment-given"), {
      postId: "post-other",
      postAuthorId: OTHER_UID,
      authorId: UID,
      authorName: "Delete Me",
      text: "Mi comentario",
      createdAt: new Date(),
    });
    batch.set(collection("post_comments").doc("comment-received"), {
      postId: "post-1",
      postAuthorId: UID,
      authorId: OTHER_UID,
      authorName: "Someone Else",
      text: "Comentario ajeno",
      createdAt: new Date(),
    });

    batch.set(collection("post_reports").doc("report-1"), {
      reportedByUserId: UID,
    });
    batch.set(collection("payments").doc("payment-1"), { userId: UID });

    batch.set(collection("visits").doc("visit-1"), {
      userId: UID,
      scannedByUserId: OTHER_UID,
      businessId: "business-1",
      memberDisplayName: "Delete Me",
      memberQrCode: "RD-delete",
      memberModality: "community",
      memberStatus: "active",
    });
    batch.set(collection("visits").doc("visit-other"), {
      userId: OTHER_UID,
      scannedByUserId: OTHER_UID,
      businessId: "business-1",
      memberDisplayName: "Someone Else",
      memberQrCode: "RD-other",
    });

    await batch.commit();
  }

  async function wipe() {
    const names = [
      "users",
      "public_profiles",
      "usernames",
      "posts",
      "follows",
      "blocks",
      "post_likes",
      "post_comments",
      "post_reports",
      "payments",
      "visits",
    ];
    for (const name of names) {
      const snapshot = await collection(name).get();
      await Promise.all(snapshot.docs.map((doc) => doc.ref.delete()));
    }
  }

  it("removes everything tied to the user and anonymizes visits", async () => {
    await wipe();
    await seed();

    const bucket = fakeBucket();
    const deleted = await deleteEnvironmentAccountData(
      db,
      bucket,
      ENVIRONMENT,
      UID,
    );

    assert.equal(deleted.profileExisted, true);
    assert.equal(deleted.posts, 2);
    assert.equal(deleted.following, 1);
    assert.equal(deleted.followers, 1);
    assert.equal(deleted.blocksMade, 1);
    assert.equal(deleted.blocksReceived, 1);
    assert.equal(deleted.likesGiven, 1);
    assert.equal(deleted.likesReceived, 1);
    assert.equal(deleted.commentsGiven, 1);
    assert.equal(deleted.commentsReceived, 1);
    assert.equal(deleted.reports, 1);
    assert.equal(deleted.payments, 1);
    assert.equal(deleted.visitsAnonymized, 1);

    assert.equal((await collection("users").doc(UID).get()).exists, false);
    assert.equal(
      (await collection("public_profiles").doc(UID).get()).exists,
      false,
    );
    assert.equal(
      (await collection("usernames").doc("deleteme").get()).exists,
      false,
    );
    assert.equal((await collection("posts").get()).size, 1);
    assert.equal((await collection("follows").get()).empty, true);
    assert.equal((await collection("blocks").get()).empty, true);
    assert.equal((await collection("post_likes").get()).empty, true);
    assert.equal((await collection("post_comments").get()).empty, true);
    assert.equal((await collection("post_reports").get()).empty, true);
    assert.equal((await collection("payments").get()).empty, true);

    assert.deepEqual(bucket.deletedPrefixes, [
      `environments/${ENVIRONMENT}/posts/${UID}/`,
      `environments/${ENVIRONMENT}/payments/${UID}/`,
      `environments/${ENVIRONMENT}/users/${UID}/`,
    ]);
  });

  it("keeps the visit record but strips the personal data", async () => {
    const visit = (await collection("visits").doc("visit-1").get()).data();

    assert.equal(visit.userId, DELETED_USER_SENTINEL);
    assert.equal(visit.memberDisplayName, DELETED_MEMBER_NAME);
    assert.equal(visit.memberQrCode, "");
    assert.equal(visit.memberDeleted, true);
    assert.equal(visit.memberModality, undefined);
    assert.equal(visit.memberStatus, undefined);
    assert.equal(visit.businessId, "business-1");

    const untouched = (await collection("visits").doc("visit-other").get())
      .data();
    assert.equal(untouched.memberDisplayName, "Someone Else");
  });

  it("is idempotent when the profile is already gone", async () => {
    const deleted = await deleteEnvironmentAccountData(
      db,
      fakeBucket(),
      ENVIRONMENT,
      UID,
    );

    assert.equal(deleted.profileExisted, false);
    assert.equal(deleted.posts, 0);
    assert.equal(deleted.followers, 0);
  });
});

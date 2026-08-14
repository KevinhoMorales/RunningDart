const { FieldValue } = require("firebase-admin/firestore");

const {
  BATCH_SIZE,
  collectionFor,
  deleteByQuery,
  updateByQuery,
} = require("./firestore_helpers");

const DELETED_USER_SENTINEL = "deleted_user";
const DELETED_MEMBER_NAME = "Cuenta eliminada";

async function deleteStoragePrefix(bucket, prefix) {
  const [files] = await bucket.getFiles({ prefix });
  await Promise.all(
    files.map((file) =>
      file.delete().catch(() => undefined),
    ),
  );
}

// Las visitas son el registro de canjes de las marcas aliadas y son inmutables
// por reglas, así que se anonimizan en lugar de borrarse. Ojo: VisitModel
// castea userId, memberDisplayName y memberQrCode como String no nulo, por eso
// se reemplazan con centinelas y no se eliminan los campos.
async function anonymizeVisits(db, environment, uid) {
  const visits = collectionFor(db, environment, "visits");
  const anonymousFields = {
    memberDeleted: true,
    anonymizedAt: FieldValue.serverTimestamp(),
    memberModality: FieldValue.delete(),
    memberStatus: FieldValue.delete(),
    expiresAt: FieldValue.delete(),
  };

  const asMember = await updateByQuery(
    db,
    visits.where("userId", "==", uid),
    {
      ...anonymousFields,
      userId: DELETED_USER_SENTINEL,
      memberDisplayName: DELETED_MEMBER_NAME,
      memberQrCode: "",
    },
  );

  const asOperator = await updateByQuery(
    db,
    visits.where("scannedByUserId", "==", uid),
    {
      ...anonymousFields,
      scannedByUserId: DELETED_USER_SENTINEL,
    },
  );

  return { asMember, asOperator };
}

// Borra en cascada todo lo que quede ligado al usuario en el ambiente dado.
// Es idempotente: si un intento anterior falló a medias, volver a llamarla
// termina el trabajo en lugar de dejar la cuenta atrapada.
async function deleteEnvironmentAccountData(db, bucket, environment, uid) {
  const userRef = collectionFor(db, environment, "users").doc(uid);
  const userSnapshot = await userRef.get();
  const username = userSnapshot.exists
    ? userSnapshot.get("username")
    : undefined;

  const posts = await deleteByQuery(
    db,
    collectionFor(db, environment, "posts").where("authorId", "==", uid),
  );
  await deleteStoragePrefix(
    bucket,
    `environments/${environment}/posts/${uid}/`,
  );

  const follows = collectionFor(db, environment, "follows");
  const following = await deleteByQuery(
    db,
    follows.where("followerId", "==", uid),
  );
  const followers = await deleteByQuery(
    db,
    follows.where("followedId", "==", uid),
  );

  const blocks = collectionFor(db, environment, "blocks");
  const blocksMade = await deleteByQuery(
    db,
    blocks.where("blockerId", "==", uid),
  );
  const blocksReceived = await deleteByQuery(
    db,
    blocks.where("blockedId", "==", uid),
  );

  // Los likes de sus publicaciones se borran junto con ellas; los que dio en
  // publicaciones ajenas hay que quitarlos aparte para que no queden colgando
  // ni sigan contando en el resumen del post.
  const postLikes = collectionFor(db, environment, "post_likes");
  const likesGiven = await deleteByQuery(
    db,
    postLikes.where("userId", "==", uid),
  );
  const likesReceived = await deleteByQuery(
    db,
    postLikes.where("postAuthorId", "==", uid),
  );

  // Igual que likes: los comentarios de sus posts caen con el post; los que
  // escribió en posts ajenos hay que limpiarlos aparte.
  const postComments = collectionFor(db, environment, "post_comments");
  const commentsGiven = await deleteByQuery(
    db,
    postComments.where("authorId", "==", uid),
  );
  const commentsReceived = await deleteByQuery(
    db,
    postComments.where("postAuthorId", "==", uid),
  );

  const reports = await deleteByQuery(
    db,
    collectionFor(db, environment, "post_reports")
      .where("reportedByUserId", "==", uid),
  );

  const payments = await deleteByQuery(
    db,
    collectionFor(db, environment, "payments").where("userId", "==", uid),
  );
  await deleteStoragePrefix(
    bucket,
    `environments/${environment}/payments/${uid}/`,
  );

  await collectionFor(db, environment, "public_profiles")
    .doc(uid)
    .delete()
    .catch(() => undefined);

  const usernames = collectionFor(db, environment, "usernames");
  if (typeof username === "string" && username.trim().length > 0) {
    await usernames
      .doc(username.trim().toLowerCase())
      .delete()
      .catch(() => undefined);
  }
  // Barrido por si la reserva quedó desincronizada del perfil.
  const usernamesReleased = await deleteByQuery(
    db,
    usernames.where("userId", "==", uid),
  );

  const visits = await anonymizeVisits(db, environment, uid);

  await deleteStoragePrefix(
    bucket,
    `environments/${environment}/users/${uid}/`,
  );

  await userRef.delete().catch(() => undefined);

  return {
    profileExisted: userSnapshot.exists,
    posts,
    following,
    followers,
    blocksMade,
    blocksReceived,
    likesGiven,
    likesReceived,
    commentsGiven,
    commentsReceived,
    reports,
    payments,
    usernamesReleased,
    visitsAnonymized: visits.asMember,
    scansAnonymized: visits.asOperator,
  };
}

module.exports = {
  BATCH_SIZE,
  DELETED_MEMBER_NAME,
  DELETED_USER_SENTINEL,
  collectionFor,
  deleteEnvironmentAccountData,
};

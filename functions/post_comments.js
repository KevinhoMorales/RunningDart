const { collectionFor, deleteByQuery } = require("./firestore_helpers");

// Recalcula el contador desde cero (igual que likes): exacto aunque el trigger
// se reintente o se pierda un evento, y nunca queda negativo.
async function syncPostCommentCount(db, environment, postId) {
  const postRef = collectionFor(db, environment, "posts").doc(postId);
  const post = await postRef.get();
  if (!post.exists) {
    return null;
  }

  const countSnapshot = await collectionFor(db, environment, "post_comments")
    .where("postId", "==", postId)
    .count()
    .get();

  const commentsCount = countSnapshot.data().count ?? 0;
  await postRef.set({ commentsCount }, { merge: true });

  return { commentsCount };
}

async function deletePostComments(db, environment, postId) {
  return deleteByQuery(
    db,
    collectionFor(db, environment, "post_comments").where("postId", "==", postId),
  );
}

module.exports = {
  deletePostComments,
  syncPostCommentCount,
};

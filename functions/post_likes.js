const { collectionFor, deleteByQuery } = require("./firestore_helpers");

// Cuántos nombres se guardan en el post para poder mostrar "Les gusta a Ana y
// Luis" sin que la app tenga que leer los likes de cada publicación del feed.
const RECENT_LIKES_LIMIT = 3;
const FALLBACK_DISPLAY_NAME = "Miembro SAINTS";

async function recentLikeProfiles(db, environment, userIds) {
  if (userIds.length === 0) {
    return [];
  }

  const profiles = collectionFor(db, environment, "public_profiles");
  const snapshots = await Promise.all(
    userIds.map((userId) => profiles.doc(userId).get()),
  );

  return snapshots.map((snapshot, index) => {
    const data = snapshot.exists ? snapshot.data() : {};
    const displayName = typeof data.displayName === "string"
      ? data.displayName.trim()
      : "";
    const photoUrl = typeof data.photoUrl === "string" ? data.photoUrl : "";

    return {
      userId: userIds[index],
      displayName: displayName || FALLBACK_DISPLAY_NAME,
      // Firestore rechaza undefined, así que el campo se omite si no hay foto.
      ...(photoUrl ? { photoUrl } : {}),
    };
  });
}

// Recalcula el resumen de likes del post desde cero en lugar de sumar o restar
// uno. Es exacto aunque el trigger se reintente o se pierda un evento, y el
// contador nunca queda negativo.
async function syncPostLikeSummary(db, environment, postId) {
  const postRef = collectionFor(db, environment, "posts").doc(postId);
  const post = await postRef.get();
  if (!post.exists) {
    return null;
  }

  const byPost = collectionFor(db, environment, "post_likes")
    .where("postId", "==", postId);

  const [countSnapshot, recentSnapshot] = await Promise.all([
    byPost.count().get(),
    byPost.orderBy("createdAt", "desc").limit(RECENT_LIKES_LIMIT).get(),
  ]);

  const likesCount = countSnapshot.data().count ?? 0;
  const userIds = recentSnapshot.docs
    .map((doc) => doc.get("userId"))
    .filter((userId) => typeof userId === "string" && userId.length > 0);
  const recentLikes = await recentLikeProfiles(db, environment, userIds);

  await postRef.set({ likesCount, recentLikes }, { merge: true });

  return { likesCount, recentLikes };
}

async function deletePostLikes(db, environment, postId) {
  return deleteByQuery(
    db,
    collectionFor(db, environment, "post_likes").where("postId", "==", postId),
  );
}

module.exports = {
  RECENT_LIKES_LIMIT,
  deletePostLikes,
  syncPostLikeSummary,
};

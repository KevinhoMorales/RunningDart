const BATCH_SIZE = 400;

function collectionFor(db, environment, name) {
  return db.collection("environments").doc(environment).collection(name);
}

// Borra por lotes para soportar consultas con muchos documentos sin agotar la
// memoria ni el límite de 500 escrituras por batch de Firestore.
async function deleteByQuery(db, query) {
  let deleted = 0;

  for (;;) {
    const snapshot = await query.limit(BATCH_SIZE).get();
    if (snapshot.empty) {
      return deleted;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;

    if (snapshot.size < BATCH_SIZE) {
      return deleted;
    }
  }
}

// Aplica los mismos campos a todos los documentos que cumplen la consulta.
async function updateByQuery(db, query, updates) {
  let updated = 0;
  let lastDoc = null;

  for (;;) {
    let page = query.limit(BATCH_SIZE);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }

    const snapshot = await page.get();
    if (snapshot.empty) {
      return updated;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.update(doc.ref, updates));
    await batch.commit();
    updated += snapshot.size;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < BATCH_SIZE) {
      return updated;
    }
  }
}

module.exports = {
  BATCH_SIZE,
  collectionFor,
  deleteByQuery,
  updateByQuery,
};

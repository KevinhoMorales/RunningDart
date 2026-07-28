const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const VALID_ENVIRONMENTS = new Set(["dev", "prod"]);
const PRO_ENTITLEMENT_ID = "SAINTS: Wellness Club Pro";

/**
 * Verifies the caller's RevenueCat subscriber record and, when the Pro
 * entitlement is active, activates SAINTS Pro Team membership in Firestore.
 *
 * Requires secret REVENUECAT_SECRET_API_KEY (Project settings → API keys →
 * Secret API key). Set with:
 *   firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
 */
exports.syncProMembershipFromRevenueCat = onCall(
  {
    secrets: ["REVENUECAT_SECRET_API_KEY"],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Debes iniciar sesión para sincronizar tu membresía.",
      );
    }

    const uid = request.auth.uid;
    const environment =
      request.data?.environment === "dev" ? "dev" : "prod";
    if (!VALID_ENVIRONMENTS.has(environment)) {
      throw new HttpsError("invalid-argument", "Ambiente no válido.");
    }

    const apiKey = process.env.REVENUECAT_SECRET_API_KEY;
    if (!apiKey) {
      logger.error("REVENUECAT_SECRET_API_KEY is not configured");
      throw new HttpsError(
        "failed-precondition",
        "RevenueCat no está configurado en el servidor.",
      );
    }

    const subscriber = await fetchRevenueCatSubscriber(uid, apiKey);
    const entitlement = subscriber?.entitlements?.[PRO_ENTITLEMENT_ID];
    if (!isEntitlementActive(entitlement)) {
      throw new HttpsError(
        "failed-precondition",
        "No hay una suscripción Pro activa para esta cuenta.",
      );
    }

    const db = getFirestore();
    const userRef = db.doc(`environments/${environment}/users/${uid}`);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "No encontramos tu perfil SAINTS.");
    }

    const userData = userSnap.data() || {};
    const now = new Date();
    const expiresAt = parseExpiresAt(entitlement.expires_date);
    const alreadyActive =
      userData.role === "member" &&
      userData.membershipStatus === "active" &&
      userData.membershipModality === "proTeam" &&
      userData.isActive === true &&
      !isExpired(userData.expiresAt, now);

    if (alreadyActive) {
      // Keep expiry in sync with the store when the subscription renews.
      if (expiresAt) {
        await userRef.update({
          expiresAt: Timestamp.fromDate(expiresAt),
        });
      }
      return { activated: false, alreadyActive: true };
    }

    await userRef.update({
      role: "member",
      membershipStatus: "active",
      membershipModality: "proTeam",
      isActive: true,
      activatedAt: Timestamp.fromDate(now),
      expiresAt: expiresAt ? Timestamp.fromDate(expiresAt) : null,
    });

    const productId =
      entitlement.product_identifier ||
      (subscriber?.subscriptions
        ? Object.keys(subscriber.subscriptions)[0]
        : null) ||
      "PRO TEAM (monthly)";
    const payments = db.collection(`environments/${environment}/payments`);
    await payments.add({
      userId: uid,
      modality: "proTeam",
      amount: 0,
      paidAt: Timestamp.fromDate(now),
      status: "approved",
      createdAt: FieldValue.serverTimestamp(),
      notes: `RevenueCat IAP · ${productId}`,
    });

    logger.info("Activated Pro membership from RevenueCat", {
      uid,
      environment,
      expiresAt: expiresAt?.toISOString() ?? null,
    });

    return { activated: true, alreadyActive: false };
  },
);

async function fetchRevenueCatSubscriber(appUserId, apiKey) {
  const url =
    "https://api.revenuecat.com/v1/subscribers/" +
    encodeURIComponent(appUserId);
  let response;
  try {
    response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    logger.error("RevenueCat request failed", { error: String(error) });
    throw new HttpsError(
      "unavailable",
      "No se pudo verificar la suscripción con RevenueCat.",
    );
  }

  if (!response.ok) {
    const body = await response.text();
    logger.error("RevenueCat subscriber lookup failed", {
      status: response.status,
      body: body.slice(0, 500),
    });
    throw new HttpsError(
      "unavailable",
      "No se pudo verificar la suscripción con RevenueCat.",
    );
  }

  const json = await response.json();
  return json.subscriber;
}

function isEntitlementActive(entitlement) {
  if (!entitlement) {
    return false;
  }
  const expires = entitlement.expires_date;
  if (expires == null) {
    // Lifetime / non-expiring entitlement.
    return true;
  }
  const expiresAt = Date.parse(expires);
  if (Number.isNaN(expiresAt)) {
    return false;
  }
  return expiresAt > Date.now();
}

function parseExpiresAt(value) {
  if (value == null || value === "") {
    return null;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function isExpired(expiresAt, now) {
  if (!expiresAt) {
    return false;
  }
  const date =
    typeof expiresAt.toDate === "function" ? expiresAt.toDate() : expiresAt;
  return date instanceof Date && date.getTime() <= now.getTime();
}

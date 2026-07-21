#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');

const ENVIRONMENT = 'prod';
const COLLECTION = 'businesses';
const DATA_FILE = path.join(__dirname, 'data', 'prod-businesses.seed.json');
const FIREBASERC_FILE = path.join(__dirname, '..', '.firebaserc');

function parseArgs(argv) {
  const apply = argv.includes('--apply');
  return { dryRun: !apply, apply };
}

function resolveProjectId() {
  if (process.env.GOOGLE_CLOUD_PROJECT) {
    return process.env.GOOGLE_CLOUD_PROJECT;
  }
  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }

  const raw = fs.readFileSync(FIREBASERC_FILE, 'utf8');
  const config = JSON.parse(raw);
  const projectId = config?.projects?.default;
  if (!projectId) {
    throw new Error('Could not resolve Firebase project id from .firebaserc.');
  }
  return projectId;
}

function loadSeedData() {
  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  const entries = JSON.parse(raw);

  if (!Array.isArray(entries) || entries.length === 0) {
    throw new Error('Seed file must contain a non-empty JSON array.');
  }

  return entries.map((entry) => {
    if (!entry.id || typeof entry.id !== 'string') {
      throw new Error('Each seed entry must include a string "id".');
    }

    const { id, ...payload } = entry;
    return { id, payload };
  });
}

function loadAccessToken() {
  if (process.env.FIREBASE_ACCESS_TOKEN) {
    return process.env.FIREBASE_ACCESS_TOKEN;
  }

  const firebaseToolsConfigPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );

  if (!fs.existsSync(firebaseToolsConfigPath)) {
    throw new Error(
      'No access token found. Run `firebase login` or set FIREBASE_ACCESS_TOKEN.',
    );
  }

  const config = JSON.parse(fs.readFileSync(firebaseToolsConfigPath, 'utf8'));
  const accessToken = config?.tokens?.access_token;
  const expiresAt = config?.tokens?.expires_at ?? 0;

  if (!accessToken) {
    throw new Error('Firebase CLI token missing. Run `firebase login`.');
  }

  if (Date.now() >= expiresAt) {
    throw new Error('Firebase CLI access token expired. Run `firebase login --reauth`.');
  }

  return accessToken;
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (typeof value === 'string') {
    return { stringValue: value };
  }
  if (typeof value === 'boolean') {
    return { booleanValue: value };
  }
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => toFirestoreValue(item)),
      },
    };
  }
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nested]) => [
            key,
            toFirestoreValue(nested),
          ]),
        ),
      },
    };
  }

  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

function toFirestoreFields(payload) {
  return Object.fromEntries(
    Object.entries(payload).map(([key, value]) => [
      key,
      toFirestoreValue(value),
    ]),
  );
}

async function writeDocument({
  projectId,
  accessToken,
  id,
  payload,
}) {
  const documentPath = `environments/${ENVIRONMENT}/${COLLECTION}/${id}`;
  const fieldPaths = Object.keys(payload);
  const updateMask = fieldPaths
    .map((fieldPath) => `updateMask.fieldPaths=${encodeURIComponent(fieldPath)}`)
    .join('&');
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/${documentPath}?${updateMask}`;

  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: toFirestoreFields(payload),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Failed to write ${documentPath}: ${response.status} ${response.statusText}\n${body}`,
    );
  }
}

async function main() {
  const { dryRun } = parseArgs(process.argv.slice(2));

  if (dryRun) {
    console.log('Running in dry-run mode (no writes). Pass --apply to write.');
  } else {
    console.log('Running in apply mode (writes enabled).');
  }

  const entries = loadSeedData();
  console.log(`Loaded ${entries.length} businesses from ${DATA_FILE}`);

  if (dryRun) {
    for (const { id, payload } of entries) {
      console.log(`[dry-run] environments/${ENVIRONMENT}/${COLLECTION}/${id}`);
      console.log(JSON.stringify(payload, null, 2));
      console.log('');
    }
    return;
  }

  const projectId = resolveProjectId();
  const accessToken = loadAccessToken();

  for (const { id, payload } of entries) {
    await writeDocument({ projectId, accessToken, id, payload });
    console.log(`Wrote environments/${ENVIRONMENT}/${COLLECTION}/${id}`);
  }

  console.log(`Successfully wrote ${entries.length} businesses to prod.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

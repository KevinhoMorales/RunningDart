#!/usr/bin/env node

// Las reglas ya no dejan listar publicaciones ocultas, así que el feed filtra
// por `isHidden` en el servidor. Los posts creados antes de ese campo no
// coinciden con `where('isHidden', '==', false)` y desaparecerían del feed:
// este script se los añade, deduciéndolo de si tienen `hiddenAt`.
//
// Correr ANTES de desplegar las reglas nuevas:
//   node scripts/backfill-post-is-hidden.js --env prod          (dry-run)
//   node scripts/backfill-post-is-hidden.js --env prod --apply

const fs = require('fs');
const os = require('os');
const path = require('path');

const VALID_ENVIRONMENTS = ['dev', 'prod'];
const COLLECTION = 'posts';
const PAGE_SIZE = 300;
const FIREBASERC_FILE = path.join(__dirname, '..', '.firebaserc');

function parseArgs(argv) {
  const apply = argv.includes('--apply');

  const envFlag = argv.indexOf('--env');
  const environment = envFlag === -1 ? 'prod' : argv[envFlag + 1];

  if (!VALID_ENVIRONMENTS.includes(environment)) {
    throw new Error(
      `--env must be one of ${VALID_ENVIRONMENTS.join(', ')}, got "${environment}".`,
    );
  }

  return { dryRun: !apply, environment };
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

function collectionUrl(projectId, environment) {
  return (
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/environments/${environment}/${COLLECTION}`
  );
}

async function listPosts({ projectId, accessToken, environment }) {
  const posts = [];
  let pageToken;

  do {
    const url = new URL(collectionUrl(projectId, environment));
    url.searchParams.set('pageSize', String(PAGE_SIZE));
    if (pageToken) {
      url.searchParams.set('pageToken', pageToken);
    }

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(
        `Failed to list posts: ${response.status} ${response.statusText}\n${body}`,
      );
    }

    const page = await response.json();
    for (const document of page.documents ?? []) {
      posts.push({
        id: document.name.split('/').pop(),
        fields: document.fields ?? {},
      });
    }
    pageToken = page.nextPageToken;
  } while (pageToken);

  return posts;
}

async function writeIsHidden({ projectId, accessToken, environment, id, isHidden }) {
  const url =
    `${collectionUrl(projectId, environment)}/${id}` +
    '?updateMask.fieldPaths=isHidden';

  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: { isHidden: { booleanValue: isHidden } } }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Failed to write post ${id}: ${response.status} ${response.statusText}\n${body}`,
    );
  }
}

async function main() {
  const { dryRun, environment } = parseArgs(process.argv.slice(2));

  console.log(
    dryRun
      ? `Running in dry-run mode against "${environment}" (no writes). Pass --apply to write.`
      : `Running in apply mode against "${environment}" (writes enabled).`,
  );

  const projectId = resolveProjectId();
  const accessToken = loadAccessToken();
  const posts = await listPosts({ projectId, accessToken, environment });

  const pending = posts
    .filter((post) => post.fields.isHidden === undefined)
    .map((post) => ({
      id: post.id,
      // Un post ya moderado tiene `hiddenAt`; el resto arranca visible.
      isHidden: post.fields.hiddenAt !== undefined,
    }));

  console.log(`Found ${posts.length} posts, ${pending.length} without isHidden.`);

  if (pending.length === 0) {
    return;
  }

  if (dryRun) {
    for (const { id, isHidden } of pending) {
      console.log(`[dry-run] ${id} -> isHidden: ${isHidden}`);
    }
    return;
  }

  for (const { id, isHidden } of pending) {
    await writeIsHidden({ projectId, accessToken, environment, id, isHidden });
    console.log(`Wrote ${id} -> isHidden: ${isHidden}`);
  }

  console.log(`Backfilled ${pending.length} posts in "${environment}".`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

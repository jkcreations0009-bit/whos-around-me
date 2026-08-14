import fs from 'node:fs';
import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

let env;
const projectId = 'demo-whos-around-me';

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/owner'), {
      visibility: 'VISIBLE_SELECTED',
      liveSharingEnabled: true,
      activeShareSessionId: 'session-abcdefghijklmnopqrstuvwxyz',
      privacyEpoch: 7,
    });
    await setDoc(doc(db, 'users/owner/sharingGrants/viewer'), {
      ownerUserId: 'owner',
      viewerUserId: 'viewer',
      relationship: 'AUTHORIZED',
      ownerApproved: true,
      viewerApproved: true,
      selectedByOwner: true,
    });
    await setDoc(
      doc(db, 'users/owner/shareSessions/session-abcdefghijklmnopqrstuvwxyz'),
      {
        ownerUserId: 'owner',
        privacyEpoch: 7,
        active: true,
        createdAtMs: 1_800_000_000_000,
        expiresAtMs: 1_800_001_800_000,
      },
    );
    await setDoc(doc(db, 'liveLocations/owner'), {
      ownerUserId: 'owner',
      sessionId: 'session-abcdefghijklmnopqrstuvwxyz',
      privacyEpoch: 7,
      latitude: 17.4065,
      longitude: 78.4772,
      accuracyMeters: 15,
      capturedAtMs: 1_800_000_000_000,
      acceptedAtMs: 1_800_000_000_500,
    });
  });
});

after(async () => {
  await env?.cleanup();
});

test('unauthenticated client cannot read private user state', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/owner')));
});

test('owner can read own privacy state but another user cannot', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  const otherDb = env.authenticatedContext('other').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'users/owner')));
  await assertFails(getDoc(doc(otherDb, 'users/owner')));
});

test('client cannot mutate server-controlled privacy state', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'users/owner'), { visibility: 'HIDDEN' }, { merge: true }),
  );
});

test('owner and viewer can inspect their grant but cannot mutate it', async () => {
  const path = 'users/owner/sharingGrants/viewer';
  const ownerDb = env.authenticatedContext('owner').firestore();
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, path)));
  await assertSucceeds(getDoc(doc(viewerDb, path)));
  await assertFails(
    setDoc(doc(viewerDb, path), { relationship: 'AUTHORIZED' }, { merge: true }),
  );
});

test('share-session metadata is owner-readable but server-write-only', async () => {
  const path = 'users/owner/shareSessions/session-abcdefghijklmnopqrstuvwxyz';
  const ownerDb = env.authenticatedContext('owner').firestore();
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, path)));
  await assertFails(getDoc(doc(viewerDb, path)));
  await assertFails(
    setDoc(doc(ownerDb, path), { active: false }, { merge: true }),
  );
});

test('no client can directly create or update a live coordinate', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'liveLocations/new-owner'), {
      ownerUserId: 'owner',
      latitude: 17.4,
      longitude: 78.4,
    }),
  );
  await assertFails(
    setDoc(
      doc(ownerDb, 'liveLocations/owner'),
      { latitude: 18.0 },
      { merge: true },
    ),
  );
});

test('even authorized owner and viewer cannot directly read coordinates', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertFails(getDoc(doc(ownerDb, 'liveLocations/owner')));
  await assertFails(getDoc(doc(viewerDb, 'liveLocations/owner')));
});

test('owner retains emergency delete while viewer cannot delete location', async () => {
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertFails(deleteDoc(doc(viewerDb, 'liveLocations/owner')));

  const ownerDb = env.authenticatedContext('owner').firestore();
  await assertSucceeds(deleteDoc(doc(ownerDb, 'liveLocations/owner')));
});

test('rules test environment is bound to demo project', () => {
  assert.equal(env.projectId, projectId);
});

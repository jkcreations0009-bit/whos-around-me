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
      visibility: 'PRIVATE_LOCAL',
      liveSharingEnabled: false,
      activeShareSessionId: null,
      privacyEpoch: 2,
    });
    await setDoc(doc(db, 'users/owner/sharingGrants/viewer'), {
      ownerUserId: 'owner',
      viewerUserId: 'viewer',
      relationship: 'AUTHORIZED',
      ownerApproved: true,
      viewerApproved: true,
      selectedByOwner: true,
    });
    await setDoc(doc(db, 'liveLocations/owner'), {
      ownerUid: 'owner',
      latitude: 17.4,
      longitude: 78.4,
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

test('owner and viewer can read their grant; unrelated user cannot', async () => {
  const path = 'users/owner/sharingGrants/viewer';
  await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(), path)));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('viewer').firestore(), path)));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), path)));
});

test('no client can directly mutate consent grant', async () => {
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertFails(
    setDoc(
      doc(viewerDb, 'users/owner/sharingGrants/viewer'),
      { relationship: 'AUTHORIZED' },
      { merge: true },
    ),
  );
});

test('live coordinate create and update stay locked for owner', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  await assertFails(
    setDoc(doc(ownerDb, 'liveLocations/new-owner'), {
      ownerUid: 'owner',
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

test('only owner can read or emergency-delete own live-location document', async () => {
  const ownerDb = env.authenticatedContext('owner').firestore();
  const viewerDb = env.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'liveLocations/owner')));
  await assertFails(getDoc(doc(viewerDb, 'liveLocations/owner')));
  await assertSucceeds(deleteDoc(doc(ownerDb, 'liveLocations/owner')));
});

test('rules test environment is bound to demo project', () => {
  assert.equal(env.projectId, projectId);
});

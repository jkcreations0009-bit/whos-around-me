import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { identityVerificationDecision } from "../common/identityVerification";

if (getApps().length === 0) initializeApp();

const strictCallableOptions = {
  enforceAppCheck: true,
  consumeAppCheckToken: true,
};

export const establishVerifiedIdentity = onCall(
  strictCallableOptions,
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    if (!request.app) {
      throw new HttpsError("failed-precondition", "App Check is required.");
    }

    const firebaseClaim = auth.token.firebase as
      | { sign_in_provider?: string }
      | undefined;
    const isAnonymous = firebaseClaim?.sign_in_provider === "anonymous";
    const authService = getAuth();
    const user = await authService.getUser(auth.uid);
    const decision = identityVerificationDecision({
      isAnonymous,
      emailVerified: user.emailVerified === true,
      hasVerifiedPhone:
        typeof user.phoneNumber === "string" && user.phoneNumber.trim().length > 0,
    });

    if (!decision.allowed || decision.method === null) {
      throw new HttpsError(
        "permission-denied",
        "A verified email address or phone number is required.",
      );
    }

    await authService.setCustomUserClaims(auth.uid, {
      ...(user.customClaims ?? {}),
      identity_verified: true,
      identity_verification_method: decision.method,
      identity_verified_at: Math.floor(Date.now() / 1000),
    });

    return {
      verified: true,
      refreshRequired: true,
    };
  },
);

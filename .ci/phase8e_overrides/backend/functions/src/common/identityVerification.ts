export interface IdentityVerificationEvidence {
  readonly isAnonymous: boolean;
  readonly emailVerified: boolean;
  readonly hasVerifiedPhone: boolean;
}

export type IdentityVerificationMethod = "EMAIL" | "PHONE";

export interface IdentityVerificationDecision {
  readonly allowed: boolean;
  readonly method: IdentityVerificationMethod | null;
}

export function identityVerificationDecision(
  evidence: IdentityVerificationEvidence,
): IdentityVerificationDecision {
  if (evidence.isAnonymous) return { allowed: false, method: null };
  if (evidence.hasVerifiedPhone) return { allowed: true, method: "PHONE" };
  if (evidence.emailVerified) return { allowed: true, method: "EMAIL" };
  return { allowed: false, method: null };
}

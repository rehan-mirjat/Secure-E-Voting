import { HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

export const JOIN_CODE_SECRET = defineSecret("JOIN_CODE_SECRET");
export const LEGACY_INVITATION_SECRET = defineSecret("LEGACY_INVITATION_SECRET");
export const LEGACY_JOIN_CODE_SECRET = defineSecret("LEGACY_JOIN_CODE_SECRET");

export function getJoinCodeSecret(): string {
  const configuredSecret = process.env.JOIN_CODE_SECRET?.trim();
  if (configuredSecret) return configuredSecret;

  if (process.env.FUNCTIONS_EMULATOR === "true" || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    return "emulator-secret-key-98765-do-not-use-in-prod";
  }

  const boundSecret = JOIN_CODE_SECRET.value().trim();
  if (boundSecret) return boundSecret;

  throw new HttpsError("failed-precondition", "Invitation service is not configured correctly.");
}

export function getLegacyJoinCodeSecret(): string | null {
  const configuredSecret = process.env.LEGACY_JOIN_CODE_SECRET?.trim();
  if (configuredSecret) return configuredSecret;

  if (process.env.FUNCTIONS_EMULATOR === "true" || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    return null;
  }

  const boundSecret = LEGACY_JOIN_CODE_SECRET.value().trim();
  return boundSecret || null;
}

export function getLegacyInvitationSecret(): string | null {
  const configuredSecret = process.env.LEGACY_INVITATION_SECRET?.trim();
  if (configuredSecret) return configuredSecret;

  if (process.env.FUNCTIONS_EMULATOR === "true" || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    return null;
  }

  const boundSecret = LEGACY_INVITATION_SECRET.value().trim();
  return boundSecret || null;
}

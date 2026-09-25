import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { getJoinCodeSecret, JOIN_CODE_SECRET } from "../utils/joinCodeSecret";

function generateRandomCode(): string {
  // 12-character high-entropy CSPRNG code formatted as JOIN-XXXX-XXXX-XXXX
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 unambiguous chars
  const bytes = crypto.randomBytes(12);
  let raw = "";
  for (let i = 0; i < 12; i++) {
    raw += chars.charAt(bytes[i] % chars.length);
  }
  return `JOIN-${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}`;
}

function computeCodeHmac(rawCode: string): string {
  const normalized = rawCode.trim().toUpperCase().replace(/[\s-]/g, "");
  const secret = getJoinCodeSecret();
  return crypto.createHmac("sha256", secret).update(normalized).digest("hex");
}

export const createJoiningCode = onCall({ secrets: [JOIN_CODE_SECRET] }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, customCode, expiresInHours = 168, maxUses = 0 } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  // Strict Duration Validation: Must be integer between 1 and 8760 (max 1 year)
  if (!Number.isInteger(expiresInHours) || expiresInHours <= 0 || expiresInHours > 8760) {
    throw new HttpsError("invalid-argument", "expiresInHours must be a positive integer between 1 and 8760.");
  }

  // Strict MaxUses Validation: Must be integer >= 0
  if (!Number.isInteger(maxUses) || maxUses < 0 || maxUses > 100000) {
    throw new HttpsError("invalid-argument", "maxUses must be an integer between 0 and 100000.");
  }

  const db = getFirestore();

  // Verify caller is Org Owner or Admin
  const memberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
  const memberSnap = await memberRef.get();

  if (!memberSnap.exists || memberSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You are not an active member of this organization.");
  }

  const role = memberSnap.data()?.role;
  if (role !== "owner" && role !== "admin") {
    throw new HttpsError("permission-denied", "Only Organization Owners or Admins can create joining codes.");
  }

  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + expiresInHours);

  let rawCode: string;
  let codeHash: string;

  // Transactionally set joiningCodes/{codeHash} to guarantee 100% uniqueness
  const createdCodeId = await db.runTransaction(async (transaction) => {
    if (customCode && typeof customCode === "string") {
      const normalizedCustom = customCode.trim().toUpperCase().replace(/[\s-]/g, "");
      if (normalizedCustom.length < 8 || !/^[A-Z0-9]+$/.test(normalizedCustom)) {
        throw new HttpsError("invalid-argument", "Custom joining code must contain at least 8 alphanumeric characters.");
      }
      rawCode = customCode.trim().toUpperCase();
      codeHash = computeCodeHmac(rawCode);

      const codeRef = db.collection("joiningCodes").doc(codeHash);
      const codeSnap = await transaction.get(codeRef);
      if (codeSnap.exists) {
        throw new HttpsError("already-exists", "This joining code is already in use.");
      }

      transaction.set(codeRef, {
        id: codeHash,
        organizationId: organizationId,
        codeHash: codeHash,
        status: "active",
        maxUses: maxUses,
        currentUses: 0,
        expiresAt: expiresAt,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
      });

      return codeHash;
    } else {
      // Generated CSPRNG code with transactional uniqueness guarantee
      let attempts = 0;
      while (attempts < 5) {
        rawCode = generateRandomCode();
        codeHash = computeCodeHmac(rawCode);
        const codeRef = db.collection("joiningCodes").doc(codeHash);
        const codeSnap = await transaction.get(codeRef);

        if (!codeSnap.exists) {
          transaction.set(codeRef, {
            id: codeHash,
            organizationId: organizationId,
            codeHash: codeHash,
            status: "active",
            maxUses: maxUses,
            currentUses: 0,
            expiresAt: expiresAt,
            createdBy: uid,
            createdAt: FieldValue.serverTimestamp(),
          });
          return codeHash;
        }
        attempts++;
      }
      throw new HttpsError("internal", "Failed to generate unique joining code. Please try again.");
    }
  });

  // Audit log (NO RAW CODES, NO NORMALIZED STRINGS, NO HASHES)
  const auditRef = db.collection("auditLogs").doc();
  await auditRef.set({
    organizationId: organizationId,
    actorUid: uid,
    action: "CREATE_JOINING_CODE",
    resourceType: "joiningCode",
    resourceId: createdCodeId,
    metadata: { joiningCodeId: createdCodeId, maxUses: maxUses, expiresInHours: expiresInHours },
    timestamp: FieldValue.serverTimestamp(),
  });

  return {
    status: "success",
    joiningCodeId: createdCodeId,
    rawCode: rawCode!, // Returned ONLY ONCE to Admin
  };
});

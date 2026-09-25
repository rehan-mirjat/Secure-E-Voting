import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as crypto from "crypto";
import {
  getJoinCodeSecret,
  getLegacyJoinCodeSecret,
  JOIN_CODE_SECRET,
  LEGACY_JOIN_CODE_SECRET,
} from "../utils/joinCodeSecret";

function computeCodeHmac(rawCode: string, secret = getJoinCodeSecret()): string {
  const normalized = rawCode.trim().toUpperCase().replace(/[\s-]/g, "");
  return crypto.createHmac("sha256", secret).update(normalized).digest("hex");
}

export const joinOrganizationWithCode = onCall(
  { secrets: [JOIN_CODE_SECRET, LEGACY_JOIN_CODE_SECRET] },
  async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { rawCode } = request.data || {};

  if (!rawCode || typeof rawCode !== "string" || rawCode.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid joining code is required.");
  }

  const db = getFirestore();

  // 1. Server-Side Email Verification Check via Firebase Auth Admin SDK
  try {
    const userAuthRecord = await getAuth().getUser(uid);
    if (!userAuthRecord.emailVerified) {
      throw new HttpsError("permission-denied", "Your email address must be verified before joining an organization.");
    }
  } catch (e: any) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("permission-denied", "Failed to verify authentication status.", e);
  }

  // 2. Validate User Account in Firestore
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists || userSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "Your account must be active to join an organization.");
  }

  // 3. Atomic Transactional Rate Limiting Check & Counter Increment
  const rateLimitRef = db.collection("joinCodeRateLimit").doc(uid);
  const now = Date.now();

  await db.runTransaction(async (transaction) => {
    const rateLimitSnap = await transaction.get(rateLimitRef);
    let attempts = 0;
    let windowStart = now;

    if (rateLimitSnap.exists) {
      const rlData = rateLimitSnap.data()!;
      windowStart = rlData.windowStart || now;
      attempts = rlData.attempts || 0;

      // 5-minute rolling window
      if (now - windowStart < 5 * 60 * 1000) {
        if (attempts >= 5) { // Exactly 5 failed attempts allowed; 6th attempt blocked
          throw new HttpsError("resource-exhausted", "Too many failed attempts. Please wait 5 minutes before trying again.");
        }
      } else {
        // Reset window
        windowStart = now;
        attempts = 0;
      }
    }

    // Atomically increment failed attempts counter inside transaction
    transaction.set(rateLimitRef, {
      windowStart: windowStart,
      attempts: attempts + 1,
    }, { merge: true });
  });

  let computedHash = computeCodeHmac(rawCode);

  // 4. Read Joining Code Document Deterministically by `codeHash`
  let codeRef = db.collection("joiningCodes").doc(computedHash);
  let codeSnap = await codeRef.get();

  // Maintain acceptance for codes issued before the HMAC key was rotated.
  if (!codeSnap.exists) {
    const legacySecret = getLegacyJoinCodeSecret();
    if (legacySecret) {
      computedHash = computeCodeHmac(rawCode, legacySecret);
      codeRef = db.collection("joiningCodes").doc(computedHash);
      codeSnap = await codeRef.get();
    }
  }

  if (!codeSnap.exists) {
    throw new HttpsError("invalid-argument", "Invalid joining code.");
  }

  const codeData = codeSnap.data()!;
  const orgId = codeData.organizationId;

  // 5. Transactional Join
  try {
    const result = await db.runTransaction(async (transaction) => {
      // FIRST: Check User Membership inside Transaction (Does NOT count as failed attempt if already member)
      const membershipRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
      const memberSnap = await transaction.get(membershipRef);

      if (memberSnap.exists && memberSnap.data()?.status === "active") {
        throw new HttpsError("already-exists", "You are already an active member of this organization.");
      }

      // Re-read code inside transaction
      const freshCodeSnap = await transaction.get(codeRef);
      if (!freshCodeSnap.exists || freshCodeSnap.data()?.status !== "active") {
        throw new HttpsError("failed-precondition", "This joining code is no longer active.");
      }

      const freshCodeData = freshCodeSnap.data()!;

      // Validate Code Expiry
      const expiresAt = freshCodeData.expiresAt ? freshCodeData.expiresAt.toDate() : null;
      if (expiresAt && expiresAt.getTime() <= Date.now()) {
        throw new HttpsError("failed-precondition", "This joining code has expired.");
      }

      // Validate Usage Limit
      const maxUses = freshCodeData.maxUses || 0;
      const currentUses = freshCodeData.currentUses || 0;
      if (maxUses > 0 && currentUses >= maxUses) {
        throw new HttpsError("failed-precondition", "This joining code has reached its maximum usage limit.");
      }

      // Validate Organization Status
      const orgRef = db.collection("organizations").doc(orgId);
      const orgSnap = await transaction.get(orgRef);

      if (!orgSnap.exists) {
        throw new HttpsError("failed-precondition", "Organization no longer exists.");
      }

      const orgStatus = orgSnap.data()?.status;
      if (orgStatus !== "active" && orgStatus !== "verified") {
        throw new HttpsError("failed-precondition", `Organization is currently ${orgStatus} and cannot accept new members.`);
      }

      // SUCCESSFUL JOIN: Transactional Writes
      // Write 1: Create Organization Member Document
      transaction.set(membershipRef, {
        membershipId: `${orgId}_${uid}`,
        organizationId: orgId,
        userId: uid,
        role: "member",
        status: "active",
        employeeId: null,
        departmentId: null,
        joinedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Write 2: Increment Code Uses
      transaction.update(codeRef, {
        currentUses: FieldValue.increment(1),
      });

      // Write 3: Audit Log (NO RAW CODES, NO NORMALIZED STRINGS, NO HASHES LOGGED)
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: orgId,
        actorUid: uid,
        action: "JOIN_ORGANIZATION_WITH_CODE",
        resourceType: "joiningCode",
        resourceId: computedHash,
        metadata: { joiningCodeId: computedHash },
        timestamp: FieldValue.serverTimestamp(),
      });

      // Clear rate limit record on successful join
      transaction.delete(rateLimitRef);

      return {
        organizationId: orgId,
        organizationName: orgSnap.data()?.name || "",
      };
    });

    return {
      status: "success",
      organizationId: result.organizationId,
      organizationName: result.organizationName,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to join organization.", error);
  }
  },
);

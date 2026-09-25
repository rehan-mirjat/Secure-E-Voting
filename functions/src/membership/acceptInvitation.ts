import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as crypto from "crypto";
import {
  getJoinCodeSecret,
  getLegacyInvitationSecret,
  getLegacyJoinCodeSecret,
  JOIN_CODE_SECRET,
  LEGACY_INVITATION_SECRET,
  LEGACY_JOIN_CODE_SECRET,
} from "../utils/joinCodeSecret";

function computeTokenHmac(rawToken: string, secret = getJoinCodeSecret()): string {
  const normalized = rawToken.trim().toUpperCase().replace(/[\s-]/g, "");
  return crypto.createHmac("sha256", secret).update(normalized).digest("hex");
}

export const acceptInvitation = onCall(
  {
    secrets: [JOIN_CODE_SECRET, LEGACY_INVITATION_SECRET, LEGACY_JOIN_CODE_SECRET],
  },
  async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { rawToken } = request.data || {};

  if (!rawToken || typeof rawToken !== "string" || rawToken.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid invitation token is required.");
  }

  const db = getFirestore();

  // 1. Server-Side Email Verification Check via Firebase Auth Admin SDK
  let userEmail = "";
  try {
    const userAuthRecord = await getAuth().getUser(uid);
    const isGoogleUser = userAuthRecord.providerData.some((p) => p.providerId === "google.com");

    if (!userAuthRecord.emailVerified && !isGoogleUser) {
      throw new HttpsError("permission-denied", "Your email address must be verified before accepting an invitation.");
    }
    userEmail = (userAuthRecord.email || "").trim().toLowerCase();
    if (!userEmail) {
      throw new HttpsError("permission-denied", "User account must have a valid email address.");
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

  // 3. Rate Limiting Check (5-minute rolling window, exactly 5 failed attempts allowed; 6th blocked)
  const rateLimitRef = db.collection("invitationRateLimit").doc(uid);
  const now = Date.now();

  const rateLimitSnap = await rateLimitRef.get();
  if (rateLimitSnap.exists) {
    const rlData = rateLimitSnap.data()!;
    const windowStart = rlData.windowStart || now;
    const attempts = rlData.attempts || 0;

    if (now - windowStart < 5 * 60 * 1000) {
      if (attempts >= 5) {
        throw new HttpsError("resource-exhausted", "Too many failed attempts. Please wait 5 minutes before trying again.");
      }
    } else {
      // Reset expired window
      await rateLimitRef.set({ windowStart: now, attempts: 0 });
    }
  }

  // Helper function to record a failed attempt EXACTLY ONCE
  const recordFailedAttempt = async () => {
    const currentSnap = await rateLimitRef.get();
    if (!currentSnap.exists || (now - (currentSnap.data()?.windowStart || 0) >= 5 * 60 * 1000)) {
      await rateLimitRef.set({ windowStart: now, attempts: 1 });
    } else {
      await rateLimitRef.update({ attempts: FieldValue.increment(1) });
    }
  };

  let computedHash = computeTokenHmac(rawToken.trim());

  // 4. Resolve Token Hash -> Opaque Invitation ID
  let tokenLookupRef = db.collection("organizationInvitationTokens").doc(computedHash);
  let tokenLookupSnap = await tokenLookupRef.get();

  // Read invitations created with either legacy fallback. New tokens always
  // use the rotated secret above.
  const legacySecrets = [
    getLegacyInvitationSecret(),
    getLegacyJoinCodeSecret(),
  ].filter((secret): secret is string => !!secret && secret !== getJoinCodeSecret());
  for (const legacySecret of legacySecrets) {
    if (tokenLookupSnap.exists) break;
    computedHash = computeTokenHmac(rawToken.trim(), legacySecret);
    tokenLookupRef = db.collection("organizationInvitationTokens").doc(computedHash);
    tokenLookupSnap = await tokenLookupRef.get();
  }

  if (!tokenLookupSnap.exists) {
    await recordFailedAttempt();
    throw new HttpsError("invalid-argument", "Invalid or expired invitation token.");
  }

  const invitationId = tokenLookupSnap.data()!.invitationId;
  const invitationRef = db.collection("organizationInvitations").doc(invitationId);
  const invitationSnap = await invitationRef.get();

  if (!invitationSnap.exists) {
    await recordFailedAttempt();
    throw new HttpsError("invalid-argument", "Invalid or expired invitation token.");
  }

  const invitationData = invitationSnap.data()!;
  const targetEmail = (invitationData.email || "").trim().toLowerCase();

  // Strict Email Matching Verification
  if (userEmail !== targetEmail) {
    await recordFailedAttempt();
    throw new HttpsError(
      "permission-denied",
      "This invitation was issued to a different email address. Please sign in with the invited email account."
    );
  }

  // 5. Transactional Acceptance
  try {
    const result = await db.runTransaction(async (transaction) => {
      const freshInvSnap = await transaction.get(invitationRef);
      if (!freshInvSnap.exists) {
        throw new HttpsError("invalid-argument", "Invitation no longer exists.");
      }

      const freshInvData = freshInvSnap.data()!;
      const orgId = freshInvData.organizationId;
      const assignedRole = freshInvData.role || "member"; // Role comes exclusively from server invitation doc

      // Check Status
      if (freshInvData.status !== "pending") {
        throw new HttpsError("failed-precondition", "This invitation is no longer valid or has already been accepted.");
      }

      // Check Expiry
      const expiresAt = freshInvData.expiresAt ? freshInvData.expiresAt.toDate() : null;
      if (expiresAt && expiresAt.getTime() <= Date.now()) {
        throw new HttpsError("failed-precondition", "This invitation has expired.");
      }

      // Check User Membership inside Transaction
      const membershipRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
      const memberSnap = await transaction.get(membershipRef);

      if (memberSnap.exists && memberSnap.data()?.status === "active") {
        throw new HttpsError("already-exists", "You are already an active member of this organization.");
      }

      // Check Organization Status
      const orgRef = db.collection("organizations").doc(orgId);
      const orgSnap = await transaction.get(orgRef);

      if (!orgSnap.exists) {
        throw new HttpsError("failed-precondition", "Organization no longer exists.");
      }

      const orgStatus = orgSnap.data()?.status;
      if (orgStatus !== "active" && orgStatus !== "verified") {
        throw new HttpsError("failed-precondition", `Organization is currently ${orgStatus} and cannot accept new members.`);
      }

      // Transactional Writes
      // Write 1: Create Organization Member Document (status == "active")
      transaction.set(membershipRef, {
        membershipId: `${orgId}_${uid}`,
        organizationId: orgId,
        userId: uid,
        role: assignedRole,
        status: "active",
        employeeId: null,
        departmentId: null,
        joinedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Write 2: Update Invitation Document (status == "accepted")
      transaction.update(invitationRef, {
        status: "accepted",
        acceptedAt: FieldValue.serverTimestamp(),
      });

      // Write 3: Delete Duplicate Lock Document so new invitations can be issued later if needed
      const lockKey = `${orgId}_${targetEmail}`;
      const lockRef = db.collection("organizationInvitationKeys").doc(lockKey);
      transaction.delete(lockRef);

      // Write 4: Delete Token Lookup Mapping to clean up token credential material
      transaction.delete(tokenLookupRef);

      // Write 5: Audit Log (resourceId is opaque invitationId; NO raw tokens/hashes logged)
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: orgId,
        actorUid: uid,
        action: "ACCEPT_INVITATION",
        resourceType: "organizationInvitation",
        resourceId: invitationId,
        metadata: {
          targetEmail: targetEmail,
          role: assignedRole,
        },
        timestamp: FieldValue.serverTimestamp(),
      });

      return {
        organizationId: orgId,
        organizationName: orgSnap.data()?.name || "",
      };
    });

    // Clear rate limit record on successful acceptance
    await rateLimitRef.delete().catch(() => {});

    return {
      status: "success",
      organizationId: result.organizationId,
      organizationName: result.organizationName,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    await recordFailedAttempt();
    throw new HttpsError("internal", "Failed to accept invitation.", error);
  }
  },
);

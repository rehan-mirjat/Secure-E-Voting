import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as crypto from "crypto";
import { getJoinCodeSecret, JOIN_CODE_SECRET } from "../utils/joinCodeSecret";

const EMAIL_REGEX = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;

function computeTokenHmac(rawToken: string): string {
  const normalized = rawToken.trim().toUpperCase().replace(/[\s-]/g, "");
  const secret = getJoinCodeSecret();
  return crypto.createHmac("sha256", secret).update(normalized).digest("hex");
}

export const inviteMember = onCall({ secrets: [JOIN_CODE_SECRET] }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, email, role = "member", expiresInHours = 168 } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!email || typeof email !== "string" || !EMAIL_REGEX.test(email.trim())) {
    throw new HttpsError("invalid-argument", "Valid email address is required.");
  }

  if (role !== "member" && role !== "admin") {
    throw new HttpsError("invalid-argument", "Role must be 'member' or 'admin'.");
  }

  if (!Number.isInteger(expiresInHours) || expiresInHours <= 0 || expiresInHours > 8760) {
    throw new HttpsError("invalid-argument", "expiresInHours must be an integer between 1 and 8760.");
  }

  const normalizedEmail = email.trim().toLowerCase();
  const db = getFirestore();

  // Verify Caller Role & Tenant Authorization
  const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
  let callerMemberSnap;
  try {
    callerMemberSnap = await callerMemberRef.get();
  } catch (error) {
    console.error("inviteMember failed to read caller membership", error);
    const details = process.env.FUNCTIONS_EMULATOR === "true"
      ? { message: error instanceof Error ? error.message : String(error) }
      : undefined;
    throw new HttpsError("internal", "Could not verify your organization membership.", details);
  }

  if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You are not an active member of this organization.");
  }

  const callerRole = callerMemberSnap.data()?.role;
  if (callerRole !== "owner" && callerRole !== "admin") {
    throw new HttpsError("permission-denied", "Only Organization Owners or Admins can issue invitations.");
  }

  // Hierarchy Restriction: Only Owner can issue Admin invitations
  if (role === "admin" && callerRole !== "owner") {
    throw new HttpsError("permission-denied", "Only the Organization Owner can issue Admin invitations.");
  }

  // Best-effort duplicate-member check. Issuing a token must not depend on the
  // Auth lookup service being available; acceptInvitation independently checks
  // the target email and rejects an already-active membership transactionally.
  try {
    const targetUser = await getAuth().getUserByEmail(normalizedEmail);
    if (targetUser && targetUser.uid) {
      const targetMemberSnap = await db.collection("organizationMembers").doc(`${organizationId}_${targetUser.uid}`).get();
      if (targetMemberSnap.exists && targetMemberSnap.data()?.status === "active") {
        throw new HttpsError("already-exists", "User with this email address is already an active member.");
      }
    }
  } catch (e: any) {
    if (e instanceof HttpsError) throw e;
    if (e?.code !== "auth/user-not-found") {
      console.warn("inviteMember recipient preflight unavailable; continuing with token issuance", {
        code: e?.code ?? "unknown",
      });
    }
  }

  // Generate 32-char CSPRNG Raw Token & HMAC Hash
  const rawToken = crypto.randomBytes(16).toString("hex"); // 32 hex chars
  const tokenHash = computeTokenHmac(rawToken);

  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + expiresInHours);

  const lockKey = `${organizationId}_${normalizedEmail}`;
  const lockRef = db.collection("organizationInvitationKeys").doc(lockKey);
  const invitationRef = db.collection("organizationInvitations").doc(); // Opaque Firestore Document ID
  const invitationId = invitationRef.id;
  const tokenLookupRef = db.collection("organizationInvitationTokens").doc(tokenHash);
  const auditRef = db.collection("auditLogs").doc();

  // Transactional Lock Claiming & Invitation Creation
  let txError: { code: any, message: string } | null = null;

  try {
    await db.runTransaction(async (transaction) => {
      const lockSnap = await transaction.get(lockRef);

      if (lockSnap.exists) {
        const existingInvId = lockSnap.data()?.invitationId;
        if (existingInvId) {
          const existingInvSnap = await transaction.get(db.collection("organizationInvitations").doc(existingInvId));
          if (existingInvSnap.exists) {
            const invData = existingInvSnap.data()!;
            const isPending = invData.status === "pending";
            const isNotExpired = invData.expiresAt ? invData.expiresAt.toDate().getTime() > Date.now() : false;

            if (isPending && isNotExpired) {
              txError = { code: "already-exists", message: "An active invitation for this email address already exists." };
              return;
            }
          }
        }
      }

      // Claim Lock Document
      transaction.set(lockRef, {
        organizationId: organizationId,
        email: normalizedEmail,
        tokenHash: tokenHash,
        invitationId: invitationId,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Write Invitation Document (keyed by opaque invitationId)
      transaction.set(invitationRef, {
        id: invitationId,
        organizationId: organizationId,
        email: normalizedEmail,
        tokenHash: tokenHash,
        role: role,
        status: "pending",
        invitedBy: uid,
        expiresAt: Timestamp.fromDate(expiresAt),
        createdAt: FieldValue.serverTimestamp(),
        acceptedAt: null,
      });

      // Write Token Lookup Mapping (tokenHash -> invitationId)
      transaction.set(tokenLookupRef, {
        invitationId: invitationId,
        tokenHash: tokenHash,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Write Audit Log Document (resourceId is opaque invitationId; NO raw token, NO tokenHash)
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "INVITE_MEMBER",
        resourceType: "organizationInvitation",
        resourceId: invitationId,
        metadata: {
          targetEmail: normalizedEmail,
          role: role,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    if (txError) {
      throw new HttpsError((txError as any).code, (txError as any).message);
    }

    return {
      status: "success",
      rawToken: rawToken, // Returned ONLY ONCE to caller
      email: normalizedEmail,
      invitationId: invitationId,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    console.error("Error in inviteMember:", error);
    const details = process.env.FUNCTIONS_EMULATOR === "true"
      ? { message: error instanceof Error ? error.message : String(error) }
      : undefined;
    throw new HttpsError("internal", "Failed to create invitation.", details);
  }
});

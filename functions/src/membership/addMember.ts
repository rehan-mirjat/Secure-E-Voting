import { getAuth, UserRecord } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Adds an existing, verified SecureVote account as a regular organization member. */
export const addMember = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const organizationId = typeof request.data?.organizationId === "string"
    ? request.data.organizationId.trim()
    : "";
  const email = typeof request.data?.email === "string"
    ? request.data.email.trim().toLowerCase()
    : "";

  if (!organizationId) {
    throw new HttpsError("invalid-argument", "A valid organizationId is required.");
  }
  if (!EMAIL_REGEX.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }

  let targetAuthUser: UserRecord;
  try {
    targetAuthUser = await getAuth().getUserByEmail(email);
  } catch (error: any) {
    if (error?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No existing SecureVote account uses that email. Send an invitation instead.");
    }
    console.error("addMember could not resolve the target account", { code: error?.code ?? "unknown" });
    throw new HttpsError("unavailable", "The member account could not be checked. Please try again.");
  }

  if (!targetAuthUser.emailVerified) {
    throw new HttpsError("failed-precondition", "The member must verify their email before being added.");
  }

  const db = getFirestore();
  const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${callerUid}`);
  const organizationRef = db.collection("organizations").doc(organizationId);
  const targetUserRef = db.collection("users").doc(targetAuthUser.uid);
  const targetMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${targetAuthUser.uid}`);
  const auditRef = db.collection("auditLogs").doc();

  try {
    await db.runTransaction(async (transaction) => {
      const [callerSnap, organizationSnap, targetUserSnap, targetMemberSnap] = await transaction.getAll(
        callerMemberRef,
        organizationRef,
        targetUserRef,
        targetMemberRef,
      );

      const caller = callerSnap.data();
      if (!callerSnap.exists || caller?.status !== "active" ||
          caller?.organizationId !== organizationId || caller?.userId !== callerUid ||
          (caller.role !== "owner" && caller.role !== "admin")) {
        throw new HttpsError("permission-denied", "Only active Organization Owners or Admins can add members.");
      }

      if (!organizationSnap.exists || !["verified", "active"].includes(organizationSnap.data()?.status)) {
        throw new HttpsError("failed-precondition", "This organization cannot accept new members right now.");
      }
      if (!targetUserSnap.exists || targetUserSnap.data()?.status !== "active" ||
          (targetUserSnap.data()?.email ?? "").trim().toLowerCase() !== email) {
        throw new HttpsError("failed-precondition", "The account is not ready to join SecureVote.");
      }
      if (targetMemberSnap.exists && targetMemberSnap.data()?.status === "active") {
        throw new HttpsError("already-exists", "This user is already an active member of the organization.");
      }
      if (targetMemberSnap.exists && targetMemberSnap.data()?.role === "owner") {
        throw new HttpsError("failed-precondition", "An Organization Owner cannot be re-added as a regular member.");
      }

      transaction.set(targetMemberRef, {
        membershipId: targetMemberRef.id,
        organizationId,
        userId: targetAuthUser.uid,
        role: "member",
        status: "active",
        employeeId: null,
        departmentId: null,
        joinedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(auditRef, {
        organizationId,
        actorUid: callerUid,
        action: "ADD_MEMBER",
        resourceType: "organizationMember",
        resourceId: targetAuthUser.uid,
        metadata: { targetEmail: email, role: "member" },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success", userId: targetAuthUser.uid, email };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("addMember failed to write membership", error);
    throw new HttpsError("internal", "The member could not be added. Please try again.");
  }
});

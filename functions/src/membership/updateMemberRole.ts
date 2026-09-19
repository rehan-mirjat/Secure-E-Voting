import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const updateMemberRole = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, targetUid, newRole } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!targetUid || typeof targetUid !== "string" || targetUid.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid targetUid is required.");
  }

  if (newRole !== "member" && newRole !== "admin") {
    throw new HttpsError("invalid-argument", "New role must be 'member' or 'admin'.");
  }

  if (uid === targetUid) {
    throw new HttpsError("permission-denied", "You cannot modify your own role through this API.");
  }

  const db = getFirestore();

  try {
    await db.runTransaction(async (transaction) => {
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const targetRef = db.collection("organizationMembers").doc(`${organizationId}_${targetUid}`);

      const [callerSnap, targetSnap] = await transaction.getAll(callerRef, targetRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerSnap.data()?.role;

      // ONLY Owners can update roles
      if (callerRole !== "owner") {
        throw new HttpsError("permission-denied", "Only Organization Owners can update member roles.");
      }

      if (!targetSnap.exists) {
        throw new HttpsError("not-found", "Target user is not a member of this organization.");
      }

      const targetRole = targetSnap.data()?.role;

      if (targetRole === "owner") {
        throw new HttpsError("permission-denied", "You cannot modify the role of another owner.");
      }

      if (targetRole === newRole) {
        throw new HttpsError("failed-precondition", `User is already assigned the role '${newRole}'.`);
      }

      // Apply update
      transaction.update(targetRef, {
        role: newRole,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "UPDATE_MEMBER_ROLE",
        resourceType: "organizationMember",
        resourceId: targetUid,
        metadata: {
          targetUid: targetUid,
          previousRole: targetRole,
          newRole: newRole,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update member role.", error);
  }
});

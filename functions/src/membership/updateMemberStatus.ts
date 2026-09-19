import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const updateMemberStatus = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, targetUid, newStatus } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!targetUid || typeof targetUid !== "string" || targetUid.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid targetUid is required.");
  }

  if (newStatus !== "active" && newStatus !== "inactive") {
    throw new HttpsError("invalid-argument", "New status must be 'active' or 'inactive'.");
  }

  if (uid === targetUid) {
    throw new HttpsError("permission-denied", "You cannot modify your own status through this API.");
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
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can modify member statuses.");
      }

      if (!targetSnap.exists) {
        throw new HttpsError("not-found", "Target user is not a member of this organization.");
      }

      const targetRole = targetSnap.data()?.role;
      const currentStatus = targetSnap.data()?.status;

      if (targetRole === "owner") {
        throw new HttpsError("permission-denied", "You cannot modify the status of an owner.");
      }

      if (targetRole === "admin" && callerRole !== "owner") {
        throw new HttpsError("permission-denied", "Only the Organization Owner can modify the status of an Admin.");
      }

      if (currentStatus === newStatus) {
        throw new HttpsError("failed-precondition", `User status is already '${newStatus}'.`);
      }

      // Apply update
      transaction.update(targetRef, {
        status: newStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "UPDATE_MEMBER_STATUS",
        resourceType: "organizationMember",
        resourceId: targetUid,
        metadata: {
          targetUid: targetUid,
          previousStatus: currentStatus,
          newStatus: newStatus,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update member status.", error);
  }
});

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const deleteDepartment = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { departmentId } = request.data || {};

  if (!departmentId || typeof departmentId !== "string" || departmentId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid departmentId is required.");
  }

  const db = getFirestore();
  const deptRef = db.collection("departments").doc(departmentId);

  try {
    await db.runTransaction(async (transaction) => {
      // 1. Fetch existing department
      const deptSnap = await transaction.get(deptRef);
      if (!deptSnap.exists) {
        throw new HttpsError("not-found", "Department not found.");
      }

      const deptData = deptSnap.data()!;
      const organizationId = deptData.organizationId;
      const normalizedName = deptData.normalizedName;
      const canonicalName = deptData.name;

      // 2. Validate Caller Membership & Role
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerMemberSnap = await transaction.get(callerMemberRef);

      if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerMemberSnap.data()?.role;
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can manage departments.");
      }

      // 3. Delete Department Document
      transaction.delete(deptRef);

      // 4. Delete Duplicate Lock
      const lockKey = `${organizationId}_${normalizedName}`;
      transaction.delete(db.collection("departmentKeys").doc(lockKey));

      // 5. Create Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "DELETE_DEPARTMENT",
        resourceType: "department",
        resourceId: departmentId,
        metadata: {
          departmentName: canonicalName,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to delete department.", error);
  }
});

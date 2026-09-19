import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const removeMemberFromDepartment = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, targetUid } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!targetUid || typeof targetUid !== "string" || targetUid.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid targetUid is required.");
  }

  const db = getFirestore();

  try {
    await db.runTransaction(async (transaction) => {
      // 1. Verify Caller is Owner/Admin in organization
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerMemberRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "Access denied.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Owners or Admins can remove members from departments.");
      }

      // 2. Verify Target User is an active member in SAME organization
      const targetMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${targetUid}`);
      const targetSnap = await transaction.get(targetMemberRef);

      if (!targetSnap.exists || targetSnap.data()?.status !== "active") {
        throw new HttpsError("not-found", "Target user is not an active member of this organization.");
      }

      const currentDepartmentId = targetSnap.data()?.departmentId;
      if (!currentDepartmentId) {
        throw new HttpsError("failed-precondition", "Target user is not assigned to any department.");
      }

      // 3. Optional Server-Side resolution of Department Name for richer audit logs
      let canonicalName = "Unknown Department";
      const deptRef = db.collection("departments").doc(currentDepartmentId);
      const deptSnap = await transaction.get(deptRef);
      if (deptSnap.exists && deptSnap.data()?.organizationId === organizationId) {
        canonicalName = deptSnap.data()!.name;
      }

      // 4. Update Target Member (Remove departmentId)
      transaction.update(targetMemberRef, {
        departmentId: null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 5. Write Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "REMOVE_DEPARTMENT",
        resourceType: "department",
        resourceId: currentDepartmentId,
        metadata: {
          targetUid: targetUid,
          departmentName: canonicalName,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to remove member from department.", error);
  }
});

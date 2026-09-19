import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const assignMemberToDepartment = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, targetUid, departmentId } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!targetUid || typeof targetUid !== "string" || targetUid.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid targetUid is required.");
  }

  if (!departmentId || typeof departmentId !== "string" || departmentId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid departmentId is required.");
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
        throw new HttpsError("permission-denied", "Only Owners or Admins can assign members to departments.");
      }

      // 2. Verify Target User is an active member in SAME organization
      const targetMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${targetUid}`);
      const targetSnap = await transaction.get(targetMemberRef);

      if (!targetSnap.exists || targetSnap.data()?.status !== "active") {
        throw new HttpsError("not-found", "Target user is not an active member of this organization.");
      }

      // 3. Verify Department exists in SAME organization
      const deptRef = db.collection("departments").doc(departmentId);
      const deptSnap = await transaction.get(deptRef);

      if (!deptSnap.exists) {
        throw new HttpsError("not-found", "Department not found.");
      }

      const deptData = deptSnap.data()!;
      if (deptData.organizationId !== organizationId) {
        throw new HttpsError("invalid-argument", "Department does not belong to this organization.");
      }

      const canonicalName = deptData.name;

      // 4. Update Target Member
      transaction.update(targetMemberRef, {
        departmentId: departmentId,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 5. Write Audit Log (Metadata resolved Server-Side)
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "ASSIGN_DEPARTMENT",
        resourceType: "department",
        resourceId: departmentId,
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
    throw new HttpsError("internal", "Failed to assign member to department.", error);
  }
});

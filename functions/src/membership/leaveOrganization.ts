import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const leaveOrganization = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  const db = getFirestore();

  try {
    await db.runTransaction(async (transaction) => {
      const memberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const memberSnap = await transaction.get(memberRef);

      if (!memberSnap.exists) {
        throw new HttpsError("not-found", "You are not a member of this organization.");
      }

      const memberData = memberSnap.data()!;
      if (memberData.status !== "active") {
        throw new HttpsError("permission-denied", "Inactive members cannot perform organization operations.");
      }

      const role = memberData.role;

      // Sole-Owner Protection Check
      if (role === "owner") {
        const ownersQuery = db.collection("organizationMembers")
          .where("organizationId", "==", organizationId)
          .where("role", "==", "owner")
          .where("status", "==", "active");

        // Transactionally execute query
        const ownersSnap = await transaction.get(ownersQuery);

        if (ownersSnap.docs.length <= 1) {
          throw new HttpsError(
            "failed-precondition",
            "Cannot leave organization. You are the sole active owner. Transfer ownership first."
          );
        }
      }

      // Hard Delete
      transaction.delete(memberRef);

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "LEAVE_ORGANIZATION",
        resourceType: "organizationMember",
        resourceId: uid,
        metadata: {
          previousRole: role,
          previousStatus: memberData.status,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to leave organization.", error);
  }
});

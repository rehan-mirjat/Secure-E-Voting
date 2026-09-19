import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const revokeJoiningCode = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { codeId } = request.data || {};

  if (!codeId || typeof codeId !== "string") {
    throw new HttpsError("invalid-argument", "Valid codeId is required.");
  }

  const db = getFirestore();
  const codeRef = db.collection("joiningCodes").doc(codeId);
  const codeSnap = await codeRef.get();

  if (!codeSnap.exists) {
    throw new HttpsError("not-found", "Joining code not found.");
  }

  const orgId = codeSnap.data()?.organizationId;
  const memberRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
  const memberSnap = await memberRef.get();

  if (!memberSnap.exists || memberSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You are not an active member of this organization.");
  }

  const role = memberSnap.data()?.role;
  if (role !== "owner" && role !== "admin") {
    throw new HttpsError("permission-denied", "Only Organization Owners or Admins can revoke joining codes.");
  }

  await codeRef.update({ status: "revoked" });

  // Audit Log
  await db.collection("auditLogs").add({
    organizationId: orgId,
    actorUid: uid,
    action: "REVOKE_JOINING_CODE",
    resourceType: "joiningCode",
    resourceId: codeId,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { status: "success" };
});

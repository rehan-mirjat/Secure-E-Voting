import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const revokeInvitation = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { invitationId } = request.data || {};

  if (!invitationId || typeof invitationId !== "string" || invitationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid invitationId is required to revoke an invitation.");
  }

  const db = getFirestore();

  // Find invitation document by opaque invitationId
  const querySnap = await db.collection("organizationInvitations")
    .where("id", "==", invitationId.trim())
    .get();

  if (querySnap.empty) {
    throw new HttpsError("not-found", "Invitation document not found.");
  }

  const invitationDoc = querySnap.docs[0];
  const invitationRef = invitationDoc.ref;

  await db.runTransaction(async (transaction) => {
    const invSnap = await transaction.get(invitationRef);
    if (!invSnap.exists) {
      throw new HttpsError("not-found", "Invitation document no longer exists.");
    }

    const invData = invSnap.data()!;
    const orgId = invData.organizationId;
    const invRole = invData.role;
    const targetEmail = invData.email;
    const tokenHash = invData.tokenHash;

    // Verify caller's membership in target organization
    const callerMemberRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
    const callerMemberSnap = await transaction.get(callerMemberRef);

    if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
      throw new HttpsError("permission-denied", "Access denied: You are not an active member of this organization.");
    }

    const callerRole = callerMemberSnap.data()?.role;
    if (callerRole !== "owner" && callerRole !== "admin") {
      throw new HttpsError("permission-denied", "Access denied: Only Owners or Admins can revoke invitations.");
    }

    // Role Revocation Hierarchy: Only Owner can revoke an Admin-level invitation
    if (invRole === "admin" && callerRole !== "owner") {
      throw new HttpsError("permission-denied", "Access denied: Only the Organization Owner can revoke an Admin-level invitation.");
    }

    // Update Invitation Status
    transaction.update(invitationRef, {
      status: "revoked",
    });

    // Delete Duplicate Lock Document so a new invitation can be re-issued
    if (targetEmail) {
      const lockRef = db.collection("organizationInvitationKeys").doc(`${orgId}_${targetEmail}`);
      transaction.delete(lockRef);
    }

    // Delete Token Lookup Mapping to clean up credential material
    if (tokenHash) {
      const tokenLookupRef = db.collection("organizationInvitationTokens").doc(tokenHash);
      transaction.delete(tokenLookupRef);
    }

    // Write Audit Log (resourceId is opaque invitationId; NO raw tokens/hashes logged)
    const auditRef = db.collection("auditLogs").doc();
    transaction.set(auditRef, {
      organizationId: orgId,
      actorUid: uid,
      action: "REVOKE_INVITATION",
      resourceType: "organizationInvitation",
      resourceId: invitationId,
      metadata: { targetEmail: targetEmail, role: invRole },
      timestamp: FieldValue.serverTimestamp(),
    });
  });

  return { status: "success" };
});

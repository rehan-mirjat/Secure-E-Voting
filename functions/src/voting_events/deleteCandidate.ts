import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

export const deleteCandidate = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { candidateId } = request.data || {};

  if (!candidateId || typeof candidateId !== "string" || candidateId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid candidateId is required.");
  }

  const db = getFirestore();
  const candRef = db.collection("candidates").doc(candidateId);

  let targetPhotoPath: string | null = null;

  try {
    // 1. Transactionally Delete Candidate Document & Audit Log
    await db.runTransaction(async (transaction) => {
      const candSnap = await transaction.get(candRef);
      if (!candSnap.exists) {
        throw new HttpsError("not-found", "Candidate not found.");
      }

      const candData = candSnap.data()!;
      const orgId = candData.organizationId;
      const votingEventId = candData.votingEventId;
      targetPhotoPath = candData.photoPath || null;

      // Validate Parent Event Status
      const eventSnap = await transaction.get(db.collection("votingEvents").doc(votingEventId));
      if (!eventSnap.exists || eventSnap.data()?.status !== "DRAFT" || eventSnap.data()?.organizationId !== orgId) {
        throw new HttpsError("failed-precondition", "Candidates can be deleted ONLY for DRAFT events.");
      }

      // Validate Caller Role
      const callerRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active" ||
          callerSnap.data()?.organizationId !== orgId || callerSnap.data()?.userId !== uid) {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can delete candidates.");
      }

      // Vote Lock Check
      const votesCheck = await transaction.get(
        db.collection("votes").where("candidateId", "==", candidateId).limit(1)
      );
      if (!votesCheck.empty) {
        throw new HttpsError("failed-precondition", "Cannot delete candidate that has cast votes.");
      }

      transaction.delete(candRef);

      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: orgId,
        actorUid: uid,
        action: "DELETE_CANDIDATE",
        resourceType: "candidate",
        resourceId: candidateId,
        metadata: {
          candidateName: candData.name,
          votingEventId: votingEventId,
        },
        timestamp: FieldValue.serverTimestamp(),
      });

      return orgId;
    });

    // 2. Post-Transaction Storage Photo Cleanup (Retry-safe)
    if (targetPhotoPath) {
      try {
        const storage = getStorage();
        const bucket = storage.bucket();
        await bucket.file(targetPhotoPath).delete();
      } catch (e) {
        // Storage cleanup errors do not fail the completed Firestore transaction
      }
    }

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to delete candidate.", error);
  }
});

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

export const finalizeCandidatePhoto = onCall(async (request) => {
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

  try {
    // 1. Fetch Candidate & Event Info inside Transaction
    const candidateData = await db.runTransaction(async (transaction) => {
      const candSnap = await transaction.get(candRef);
      if (!candSnap.exists) {
        throw new HttpsError("not-found", "Candidate not found.");
      }

      const candData = candSnap.data()!;
      const organizationId = candData.organizationId;
      const votingEventId = candData.votingEventId;

      // Validate Caller Membership & Role
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can finalize candidate photos.");
      }

      // Validate Parent Event Status
      const eventSnap = await transaction.get(db.collection("votingEvents").doc(votingEventId));
      if (!eventSnap.exists || eventSnap.data()?.status !== "DRAFT") {
        throw new HttpsError("failed-precondition", "Candidate photo can be finalized ONLY for DRAFT events.");
      }

      return candData;
    });

    const organizationId = candidateData.organizationId;
    const votingEventId = candidateData.votingEventId;
    const expectedPhotoPath = `organizations/${organizationId}/events/${votingEventId}/candidates/${candidateId}/photo.jpg`;

    // 2. Storage Bucket File Verification
    const storage = getStorage();
    const bucket = storage.bucket("e-voteing-system.appspot.com");
    const file = bucket.file(expectedPhotoPath);

    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError(
        "failed-precondition",
        `Storage file '${expectedPhotoPath}' does not exist. Upload photo before finalization.`
      );
    }

    const [metadata] = await file.getMetadata();
    if (metadata.contentType !== "image/jpeg") {
      throw new HttpsError("invalid-argument", "Candidate photo must be a valid 'image/jpeg'.");
    }

    const fileSize = Number(metadata.size) || 0;
    if (fileSize <= 0 || fileSize > 5 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "Candidate photo size must be between 1 byte and 5MB.");
    }

    // Public/Download URL generation for Storage emulator or production
    const photoUrl = `http://127.0.0.1:9199/v0/b/${bucket.name}/o/${encodeURIComponent(expectedPhotoPath)}?alt=media`;

    // 3. Transactionally Set photoPath & photoUrl as Atomic Pair
    await db.runTransaction(async (transaction) => {
      transaction.update(candRef, {
        photoPath: expectedPhotoPath,
        photoUrl: photoUrl,
        updatedAt: FieldValue.serverTimestamp(),
      });

      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "FINALIZE_CANDIDATE_PHOTO",
        resourceType: "candidate",
        resourceId: candidateId,
        metadata: {
          photoPath: expectedPhotoPath,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return {
      status: "success",
      photoPath: expectedPhotoPath,
      photoUrl: photoUrl,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to finalize candidate photo.", error);
  }
});

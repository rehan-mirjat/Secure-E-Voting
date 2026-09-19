import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const createCandidate = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting
  const allowedKeys = ["organizationId", "votingEventId", "name", "party", "bio"];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter '${key}' in createCandidate payload.`);
    }
  }

  const { organizationId, votingEventId, name, party, bio } = data;

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!votingEventId || typeof votingEventId !== "string" || votingEventId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid votingEventId is required.");
  }

  if (!name || typeof name !== "string" || name.trim().length < 3 || name.trim().length > 100) {
    throw new HttpsError("invalid-argument", "Candidate name must be between 3 and 100 characters.");
  }

  const cleanParty = party && typeof party === "string" ? party.trim() : "";
  if (cleanParty.length > 100) {
    throw new HttpsError("invalid-argument", "Party name cannot exceed 100 characters.");
  }

  const cleanBio = bio && typeof bio === "string" ? bio.trim() : "";
  if (cleanBio.length > 1000) {
    throw new HttpsError("invalid-argument", "Bio cannot exceed 1000 characters.");
  }

  const db = getFirestore();

  try {
    const candidateRef = db.collection("candidates").doc();
    const candidateId = candidateRef.id;
    const expectedPhotoPath = `organizations/${organizationId}/events/${votingEventId}/candidates/${candidateId}/photo.jpg`;

    await db.runTransaction(async (transaction) => {
      // 1. Verify parent event
      const eventRef = db.collection("votingEvents").doc(votingEventId);
      const eventSnap = await transaction.get(eventRef);

      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Target voting event not found.");
      }

      const eventData = eventSnap.data()!;
      if (eventData.organizationId !== organizationId) {
        throw new HttpsError("permission-denied", "Voting event belongs to a different organization.");
      }

      if (eventData.status !== "DRAFT") {
        throw new HttpsError("failed-precondition", `Candidates can be created ONLY for DRAFT events. Current status: '${eventData.status}'`);
      }

      if (eventData.votingType !== "CANDIDATE_ELECTION") {
        throw new HttpsError("failed-precondition", `Candidates can be created ONLY for CANDIDATE_ELECTION events. Event type: '${eventData.votingType}'`);
      }

      // 2. Verify caller role
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can create candidates.");
      }

      // 3. Create Candidate Document (photoUrl & photoPath set to null initially)
      transaction.set(candidateRef, {
        id: candidateId,
        organizationId: organizationId,
        votingEventId: votingEventId,
        name: name.trim(),
        party: cleanParty,
        bio: cleanBio,
        photoUrl: null,
        photoPath: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 4. Atomic Audit Log Creation
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "CREATE_CANDIDATE",
        resourceType: "candidate",
        resourceId: candidateId,
        metadata: {
          candidateName: name.trim(),
          votingEventId: votingEventId,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return {
      status: "success",
      candidateId: candidateId,
      expectedPhotoPath: expectedPhotoPath,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to create candidate.", error);
  }
});

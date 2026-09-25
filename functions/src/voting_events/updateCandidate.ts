import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const updateCandidate = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting
  const allowedKeys = ["candidateId", "name", "party", "bio"];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter '${key}' in updateCandidate payload.`);
    }
  }

  const { candidateId, name, party, bio } = data;

  if (!candidateId || typeof candidateId !== "string" || candidateId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid candidateId is required.");
  }

  const db = getFirestore();
  const candRef = db.collection("candidates").doc(candidateId);

  try {
    await db.runTransaction(async (transaction) => {
      const candSnap = await transaction.get(candRef);
      if (!candSnap.exists) {
        throw new HttpsError("not-found", "Candidate not found.");
      }

      const candData = candSnap.data()!;
      const organizationId = candData.organizationId;
      const votingEventId = candData.votingEventId;

      // Validate Parent Event Status
      const eventSnap = await transaction.get(db.collection("votingEvents").doc(votingEventId));
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Voting event not found.");
      }

      const eventStatus = eventSnap.data()?.status;
      if (eventStatus !== "DRAFT") {
        throw new HttpsError("failed-precondition", `Candidates can be updated ONLY in DRAFT events. Current status: '${eventStatus}'`);
      }

      // Validate Caller Role
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active" ||
          callerSnap.data()?.organizationId !== organizationId || callerSnap.data()?.userId !== uid) {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can update candidates.");
      }

      const updates: any = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (name !== undefined) {
        if (typeof name !== "string" || name.trim().length < 3 || name.trim().length > 100) {
          throw new HttpsError("invalid-argument", "Candidate name must be between 3 and 100 characters.");
        }
        updates.name = name.trim();
      }

      if (party !== undefined) {
        const cleanParty = typeof party === "string" ? party.trim() : "";
        if (cleanParty.length > 100) {
          throw new HttpsError("invalid-argument", "Party name cannot exceed 100 characters.");
        }
        updates.party = cleanParty;
      }

      if (bio !== undefined) {
        const cleanBio = typeof bio === "string" ? bio.trim() : "";
        if (cleanBio.length > 1000) {
          throw new HttpsError("invalid-argument", "Bio cannot exceed 1000 characters.");
        }
        updates.bio = cleanBio;
      }

      transaction.update(candRef, updates);

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "UPDATE_CANDIDATE",
        resourceType: "candidate",
        resourceId: candidateId,
        metadata: {
          candidateName: updates.name || candData.name,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update candidate.", error);
  }
});

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { checkVoterEligibility } from "../utils/checkVoterEligibility";
import { validateChoiceReference } from "../utils/choiceValidation";
import { validateAnonymousBallotPayload, validateParticipationPayload } from "../utils/privacyValidation";
import { generateVoteReceipt } from "./generateReceipt";

export const castVote = onCall(async (request) => {
  // 1. Authenticate caller
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated to cast a ballot.");
  }

  const uid = request.auth.uid;
  const db = getFirestore();

  const { organizationId, eventId, candidateId, pollOptionId } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!eventId || typeof eventId !== "string" || eventId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid eventId is required.");
  }

  const cleanOrgId = organizationId.trim();
  const cleanEventId = eventId.trim();
  const cleanCandidateId = candidateId && typeof candidateId === "string" ? candidateId.trim() : null;
  const cleanPollOptionId = pollOptionId && typeof pollOptionId === "string" ? pollOptionId.trim() : null;

  try {
    const result = await db.runTransaction(async (transaction) => {
      // --- READ PHASE (ALL READS MUST OCCUR BEFORE WRITES) ---

      // Read 1: User Profile
      const userRef = db.collection("users").doc(uid);
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists || userSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "User profile is inactive or non-existent.");
      }

      // Read 2: Participation Doc (Deterministic key: `${orgId}_${eventId}_${uid}`)
      const participationRef = db.collection("participation").doc(`${cleanOrgId}_${cleanEventId}_${uid}`);
      const participationSnap = await transaction.get(participationRef);
      if (participationSnap.exists) {
        throw new HttpsError("failed-precondition", "You have already voted in this voting event.");
      }

      // Read 3: Voting Event Doc
      const eventRef = db.collection("votingEvents").doc(cleanEventId);
      const eventSnap = await transaction.get(eventRef);
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Target voting event not found.");
      }

      const eventData = eventSnap.data()!;
      if (eventData.organizationId !== cleanOrgId) {
        throw new HttpsError("permission-denied", "Voting event belongs to a different organization.");
      }

      if (eventData.status !== "ACTIVE") {
        throw new HttpsError("failed-precondition", `Voting event is not currently active (Status: ${eventData.status}).`);
      }

      const nowMillis = Date.now();
      const startMillis = (eventData.startAt as Timestamp).toMillis();
      const endMillis = (eventData.endAt as Timestamp).toMillis();

      if (nowMillis < startMillis) {
        throw new HttpsError("failed-precondition", "Voting window has not opened yet.");
      }

      if (nowMillis > endMillis) {
        throw new HttpsError("failed-precondition", "Voting window has closed.");
      }

      // Read 4: Eligibility Check (performs transaction reads on member and dept docs)
      await checkVoterEligibility(transaction, db, {
        organizationId: cleanOrgId,
        eventId: cleanEventId,
        userId: uid,
      });

      // Read 5: Choice Reference Validation (performs transaction reads on candidate/option docs)
      const choiceResult = await validateChoiceReference(transaction, db, {
        organizationId: cleanOrgId,
        eventId: cleanEventId,
        candidateId: cleanCandidateId,
        pollOptionId: cleanPollOptionId,
      });

      // --- WRITE PHASE (ALL WRITES AFTER READS) ---

      // 1. Prepare Anonymous Vote Document
      const voteRef = db.collection("votes").doc();
      const voteData: Record<string, any> = {
        organizationId: cleanOrgId,
        votingEventId: cleanEventId,
        castAt: FieldValue.serverTimestamp(),
      };
      if (choiceResult.choiceType === "CANDIDATE") {
        voteData.candidateId = choiceResult.choiceId;
      } else {
        voteData.pollOptionId = choiceResult.choiceId;
      }

      // Validate ballot payload strictly enforces ZERO voter identity
      validateAnonymousBallotPayload(voteData);

      // 2. Prepare Participation Document
      const participationData: Record<string, any> = {
        organizationId: cleanOrgId,
        votingEventId: cleanEventId,
        userId: uid,
        votedAt: FieldValue.serverTimestamp(),
      };

      // Validate participation payload strictly enforces ZERO choice metadata
      validateParticipationPayload(participationData);

      // 3. Prepare Vote Receipt
      const receiptDataObj = generateVoteReceipt(cleanOrgId, cleanEventId, uid, nowMillis);
      const receiptRef = db.collection("voteReceipts").doc();
      const receiptRecord = {
        id: receiptRef.id,
        organizationId: cleanOrgId,
        votingEventId: cleanEventId,
        userId: uid,
        votedAt: FieldValue.serverTimestamp(),
        receiptHash: receiptDataObj.receiptHash,
      };

      // 4. Prepare Audit Log
      const auditRef = db.collection("auditLogs").doc();
      const auditData = {
        organizationId: cleanOrgId,
        actorUid: uid,
        action: "CAST_VOTE_BALLOT",
        resourceType: "votingEvent",
        resourceId: cleanEventId,
        metadata: {
          votingType: eventData.votingType,
          receiptId: receiptRef.id,
        },
        timestamp: FieldValue.serverTimestamp(),
      };

      // --- EXECUTE TRANSACTION WRITES ---
      transaction.set(voteRef, voteData);
      transaction.set(participationRef, participationData);
      transaction.set(receiptRef, receiptRecord);
      transaction.set(auditRef, auditData);

      return {
        receiptId: receiptRef.id,
        receiptHash: receiptDataObj.receiptHash,
        votedAt: new Date(nowMillis).toISOString(),
      };
    });

    return { status: "success", ...result };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to cast ballot. Please try again.", error);
  }
});

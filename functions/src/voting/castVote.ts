import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { generateVoteReceipt } from "./generateReceipt";
import { checkVoterEligibility } from "../utils/checkVoterEligibility";
import { validateChoiceReference } from "../utils/choiceValidation";
import { validateAnonymousBallotPayload, validateIdentifiableBallotPayload } from "../utils/privacyValidation";

export interface CastVoteRequest {
  organizationId: string;
  eventId: string;
  candidateId?: string;
  pollOptionId?: string;
}

/**
 * Server-authoritative double-entry voting transaction engine with privacy mode branching.
 * Batch-fetches all transaction documents in 1 parallel network request to optimize latency.
 */
export const castVote = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required to cast a vote.");
  }

  const data = request.data as CastVoteRequest;
  const { organizationId, eventId, candidateId, pollOptionId } = data || {};

  if (!organizationId || !eventId) {
    throw new HttpsError("invalid-argument", "organizationId and eventId are strictly required.");
  }

  const cleanOrgId = organizationId.trim();
  const cleanEventId = eventId.trim();
  const cleanCandidateId = candidateId?.trim();
  const cleanPollOptionId = pollOptionId?.trim();

  const db = getFirestore();

  try {
    const result = await db.runTransaction(async (transaction) => {
      // --- READ PHASE: BATCH ALL DOC READS IN 1 PARALLEL REQUEST ---
      const userRef = db.collection("users").doc(uid);
      const participationRef = db.collection("participation").doc(`${cleanOrgId}_${cleanEventId}_${uid}`);
      const eventRef = db.collection("votingEvents").doc(cleanEventId);
      const memberRef = db.collection("organizationMembers").doc(`${cleanOrgId}_${uid}`);
      const organizationRef = db.collection("organizations").doc(cleanOrgId);
      const [userSnap, participationSnap, eventSnap, memberSnap, organizationSnap] =
        await transaction.getAll(userRef, participationRef, eventRef, memberRef, organizationRef);

      // Read 1: User Profile Validation
      if (!userSnap.exists || userSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "User profile is inactive or non-existent.");
      }

      // Read 2: Participation Check (Deterministic duplicate prevention)
      if (participationSnap.exists) {
        throw new HttpsError("failed-precondition", "You have already voted in this voting event.");
      }

      // Read 3: Voting Event Validation
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Target voting event not found.");
      }

      const eventData = eventSnap.data()!;
      if (eventData.organizationId !== cleanOrgId) {
        throw new HttpsError("permission-denied", "Voting event belongs to a different organization.");
      }

      if (!organizationSnap.exists || !["verified", "active"].includes(organizationSnap.data()?.status)) {
        throw new HttpsError("failed-precondition", "This organization is not currently authorized to run voting events.");
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

      if (nowMillis >= endMillis) {
        throw new HttpsError("failed-precondition", "Voting window has closed.");
      }

      // Read 4: Eligibility Check (passes pre-fetched snaps)
      await checkVoterEligibility(
        transaction,
        db,
        { organizationId: cleanOrgId, eventId: cleanEventId, userId: uid },
        { memberSnap, eventSnap }
      );

      // Read 5: Choice Reference Validation (passes pre-fetched snaps)
      const choiceResult = await validateChoiceReference(
        transaction,
        db,
        {
          organizationId: cleanOrgId,
          eventId: cleanEventId,
          candidateId: cleanCandidateId,
          pollOptionId: cleanPollOptionId,
        }
      );

      // --- PRIVACY MODE BRANCHING & WRITE PHASE ---
      const privacyMode = (eventData.privacyMode || "anonymous").toUpperCase();
      const votesRef = db.collection("votes").doc();
      const nowTs = Timestamp.now();

      if (privacyMode === "IDENTIFIABLE") {
        validateIdentifiableBallotPayload({
          organizationId: cleanOrgId,
          votingEventId: cleanEventId,
          ...(cleanCandidateId ? { candidateId: cleanCandidateId } : { pollOptionId: cleanPollOptionId }),
          castAt: nowTs,
          userId: uid,
        }, uid);
        transaction.set(votesRef, {
          organizationId: cleanOrgId,
          votingEventId: cleanEventId,
          privacyMode: "IDENTIFIABLE",
          choiceType: choiceResult.choiceType,
          choiceId: choiceResult.choiceId,
          userId: uid,
          createdAt: nowTs,
        });
      } else {
        validateAnonymousBallotPayload({
          organizationId: cleanOrgId,
          votingEventId: cleanEventId,
          ...(cleanCandidateId ? { candidateId: cleanCandidateId } : { pollOptionId: cleanPollOptionId }),
          castAt: nowTs,
        });
        transaction.set(votesRef, {
          organizationId: cleanOrgId,
          votingEventId: cleanEventId,
          privacyMode: "ANONYMOUS",
          choiceType: choiceResult.choiceType,
          choiceId: choiceResult.choiceId,
          createdAt: nowTs,
        });
      }

      // Write 2: Atomic Participation Record
      transaction.set(participationRef, {
        organizationId: cleanOrgId,
        votingEventId: cleanEventId,
        userId: uid,
        votedAt: nowTs,
      });

      // Write 3: Atomic Ballot Receipt
      const receipt = generateVoteReceipt(cleanOrgId, cleanEventId, uid, nowTs.toMillis());
      const receiptRef = db.collection("voteReceipts").doc(receipt.receiptId);
      // A receipt proves acceptance/participation, never points to the ballot.
      // In anonymous mode even an application-level receipt→vote link is forbidden.
      transaction.set(receiptRef, {
        organizationId: cleanOrgId,
        votingEventId: cleanEventId,
        userId: uid,
        receiptHash: receipt.receiptHash,
        privacyMode,
        votedAt: nowTs,
      });

      return {
        status: "success",
        receiptId: receiptRef.id,
        privacyMode: privacyMode,
        votedAt: nowTs.toDate().toISOString(),
        receiptHash: receipt.receiptHash,
      };
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", `An error occurred while processing your vote: ${(error as Error).message}`);
  }
});

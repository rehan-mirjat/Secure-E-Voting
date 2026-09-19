import { HttpsError } from "firebase-functions/v2/https";
import { Transaction, Firestore } from "firebase-admin/firestore";

export interface ChoiceValidationRequest {
  organizationId: string;
  eventId: string;
  candidateId?: string | null;
  pollOptionId?: string | null;
}

/**
 * Server-authoritative double-ownership & type-compatibility choice validation gate.
 * Verifies that the supplied choice belongs to the correct organization AND event,
 * and matches the event's votingType contract.
 */
export async function validateChoiceReference(
  transaction: Transaction,
  db: Firestore,
  req: ChoiceValidationRequest
): Promise<{ choiceType: "CANDIDATE" | "POLL_OPTION"; choiceId: string }> {
  const { organizationId, eventId, candidateId, pollOptionId } = req;

  if (!organizationId || !eventId) {
    throw new HttpsError("invalid-argument", "organizationId and eventId are required for choice validation.");
  }

  // Reject conflicting or missing choice payloads
  if (candidateId && pollOptionId) {
    throw new HttpsError("invalid-argument", "Cannot supply both candidateId and pollOptionId in the same choice payload.");
  }

  if (!candidateId && !pollOptionId) {
    throw new HttpsError("invalid-argument", "Choice payload must contain either candidateId or pollOptionId.");
  }

  const eventRef = db.collection("votingEvents").doc(eventId);
  const eventSnap = await transaction.get(eventRef);

  if (!eventSnap.exists) {
    throw new HttpsError("not-found", "Target voting event not found.");
  }

  const eventData = eventSnap.data()!;
  if (eventData.organizationId !== organizationId) {
    throw new HttpsError("invalid-argument", "Target voting event does not belong to the specified organization.");
  }

  const votingType = eventData.votingType;

  // 1. Candidate Election Choice Validation
  if (votingType === "CANDIDATE_ELECTION") {
    if (!candidateId) {
      throw new HttpsError("invalid-argument", "CANDIDATE_ELECTION requires a candidateId.");
    }

    const candRef = db.collection("candidates").doc(candidateId);
    const candSnap = await transaction.get(candRef);

    if (!candSnap.exists) {
      throw new HttpsError("not-found", `Candidate '${candidateId}' does not exist.`);
    }

    const candData = candSnap.data()!;
    // Double-Ownership Verification: Candidate MUST belong to SAME org AND SAME event
    if (candData.organizationId !== organizationId || candData.votingEventId !== eventId) {
      throw new HttpsError("invalid-argument", "Candidate ownership metadata mismatch (candidate does not belong to this event/org).");
    }

    return { choiceType: "CANDIDATE", choiceId: candidateId };
  }

  // 2. Single-Choice Poll Validation
  if (votingType === "SINGLE_CHOICE_POLL") {
    if (!pollOptionId) {
      throw new HttpsError("invalid-argument", "SINGLE_CHOICE_POLL requires a pollOptionId.");
    }

    const optRef = db.collection("pollOptions").doc(pollOptionId);
    const optSnap = await transaction.get(optRef);

    if (!optSnap.exists) {
      throw new HttpsError("not-found", `Poll option '${pollOptionId}' does not exist.`);
    }

    const optData = optSnap.data()!;
    // Double-Ownership Verification: Poll option MUST belong to SAME org AND SAME event
    if (optData.organizationId !== organizationId || optData.votingEventId !== eventId) {
      throw new HttpsError("invalid-argument", "Poll option ownership metadata mismatch (option does not belong to this event/org).");
    }

    return { choiceType: "POLL_OPTION", choiceId: pollOptionId };
  }

  // 3. Yes/No Poll Validation
  if (votingType === "YES_NO_POLL") {
    if (!pollOptionId) {
      throw new HttpsError("invalid-argument", "YES_NO_POLL requires a pollOptionId.");
    }

    const expectedYesId = `${eventId}_YES`;
    const expectedNoId = `${eventId}_NO`;

    if (pollOptionId !== expectedYesId && pollOptionId !== expectedNoId) {
      throw new HttpsError("invalid-argument", "YES_NO_POLL accepts ONLY generated '{eventId}_YES' or '{eventId}_NO' poll options.");
    }

    const optRef = db.collection("pollOptions").doc(pollOptionId);
    const optSnap = await transaction.get(optRef);

    if (!optSnap.exists) {
      throw new HttpsError("not-found", `Generated Yes/No poll option '${pollOptionId}' does not exist.`);
    }

    const optData = optSnap.data()!;
    if (optData.organizationId !== organizationId || optData.votingEventId !== eventId) {
      throw new HttpsError("invalid-argument", "Yes/No option ownership metadata mismatch.");
    }

    return { choiceType: "POLL_OPTION", choiceId: pollOptionId };
  }

  throw new HttpsError("invalid-argument", `Unsupported votingType '${votingType}'.`);
}

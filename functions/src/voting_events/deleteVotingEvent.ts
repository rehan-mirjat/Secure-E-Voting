import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const deleteVotingEvent = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { eventId } = request.data || {};

  if (!eventId || typeof eventId !== "string" || eventId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid eventId is required.");
  }

  const db = getFirestore();
  const eventRef = db.collection("votingEvents").doc(eventId);

  try {
    await db.runTransaction(async (transaction) => {
      const eventSnap = await transaction.get(eventRef);
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Voting event not found.");
      }

      const eventData = eventSnap.data()!;
      const organizationId = eventData.organizationId;
      const currentStatus = eventData.status;

      // Hard Delete Guard: DRAFT status ONLY
      if (currentStatus !== "DRAFT") {
        throw new HttpsError(
          "failed-precondition",
          `Only DRAFT voting events can be deleted. Event in status '${currentStatus}' cannot be deleted.`
        );
      }

      // Validate Caller Membership & Role
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerMemberSnap = await transaction.get(callerMemberRef);

      if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerMemberSnap.data()?.role;
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can delete voting events.");
      }

      // Vote Lock Check: Verify zero votes or participation records exist
      const votesCheck = await transaction.get(
        db.collection("votes").where("eventId", "==", eventId).limit(1)
      );
      if (!votesCheck.empty) {
        throw new HttpsError("failed-precondition", "Cannot delete voting event that contains cast votes.");
      }

      // Cascade Delete candidates and pollOptions sub-documents
      const candidatesSnap = await transaction.get(
        db.collection("candidates").where("votingEventId", "==", eventId)
      );
      for (const candDoc of candidatesSnap.docs) {
        transaction.delete(candDoc.ref);
      }

      const optionsSnap = await transaction.get(
        db.collection("pollOptions").where("votingEventId", "==", eventId)
      );
      for (const optDoc of optionsSnap.docs) {
        transaction.delete(optDoc.ref);
      }

      // Also explicitly attempt deleting deterministic YES/NO options if YES_NO_POLL
      transaction.delete(db.collection("pollOptions").doc(`${eventId}_YES`));
      transaction.delete(db.collection("pollOptions").doc(`${eventId}_NO`));

      // Delete Voting Event Document
      transaction.delete(eventRef);

      // Audit Log with stable metadata
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "DELETE_VOTING_EVENT",
        resourceType: "votingEvent",
        resourceId: eventId,
        metadata: {
          title: eventData.title,
          deletedStatus: "DRAFT",
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to delete voting event.", error);
  }
});

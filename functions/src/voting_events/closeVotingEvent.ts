import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const closeVotingEvent = onCall(async (request) => {
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

      // Strict Transition: ACTIVE -> CLOSED only
      if (currentStatus !== "ACTIVE") {
        throw new HttpsError("failed-precondition", `Only ACTIVE events can be closed. Current status: '${currentStatus}'`);
      }

      // Validate Caller Membership & Role
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerMemberSnap = await transaction.get(callerMemberRef);

      if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerMemberSnap.data()?.role;
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can close voting events.");
      }

      transaction.update(eventRef, {
        status: "CLOSED",
        closedAt: FieldValue.serverTimestamp(),
        closedBy: uid,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "CLOSE_VOTING_EVENT",
        resourceType: "votingEvent",
        resourceId: eventId,
        metadata: {
          previousStatus: "ACTIVE",
          newStatus: "CLOSED",
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to close voting event.", error);
  }
});

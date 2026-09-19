import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

/**
 * Server-Controlled Automatic Lifecycle Evaluator.
 * Transition SCHEDULED -> ACTIVE (if startAt <= trustedNow)
 * Transition ACTIVE -> CLOSED (if endAt <= trustedNow)
 * Can be called periodically by Cloud Scheduler or invoked safely via Callable.
 * Idempotent with transactional precondition guards.
 */
export const evaluateVotingEventLifecycles = onCall(async (request) => {
  const db = getFirestore();
  const trustedNow = Timestamp.now();

  let activatedCount = 0;
  let closedCount = 0;

  try {
    // 1. Find SCHEDULED events due for activation
    const scheduledSnap = await db
      .collection("votingEvents")
      .where("status", "==", "SCHEDULED")
      .where("startAt", "<=", trustedNow)
      .get();

    for (const eventDoc of scheduledSnap.docs) {
      await db.runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(eventDoc.ref);
        if (freshSnap.exists && freshSnap.data()?.status === "SCHEDULED") {
          transaction.update(eventDoc.ref, {
            status: "ACTIVE",
            updatedAt: FieldValue.serverTimestamp(),
          });
          activatedCount++;
        }
      });
    }

    // 2. Find ACTIVE events due for closure
    const activeSnap = await db
      .collection("votingEvents")
      .where("status", "==", "ACTIVE")
      .where("endAt", "<=", trustedNow)
      .get();

    for (const eventDoc of activeSnap.docs) {
      await db.runTransaction(async (transaction) => {
        const freshSnap = await transaction.get(eventDoc.ref);
        if (freshSnap.exists && freshSnap.data()?.status === "ACTIVE") {
          transaction.update(eventDoc.ref, {
            status: "CLOSED",
            closedAt: FieldValue.serverTimestamp(),
            closedBy: "SYSTEM_SCHEDULED_EVALUATOR",
            updatedAt: FieldValue.serverTimestamp(),
          });

          // Audit Log
          const auditRef = db.collection("auditLogs").doc();
          transaction.set(auditRef, {
            organizationId: freshSnap.data()?.organizationId,
            actorUid: "SYSTEM_SCHEDULED_EVALUATOR",
            action: "CLOSE_VOTING_EVENT",
            resourceType: "votingEvent",
            resourceId: eventDoc.id,
            metadata: {
              previousStatus: "ACTIVE",
              newStatus: "CLOSED",
              reason: "Automatic schedule completion",
            },
            timestamp: FieldValue.serverTimestamp(),
          });
          closedCount++;
        }
      });
    }

    return {
      status: "success",
      activatedCount: activatedCount,
      closedCount: closedCount,
    };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to evaluate voting event lifecycles.", error);
  }
});

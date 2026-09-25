import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

/**
 * Server-Controlled Automatic Lifecycle Evaluator.
 * Transition SCHEDULED -> ACTIVE (if startAt <= trustedNow)
 * Transition ACTIVE -> CLOSED (if endAt <= trustedNow)
 * Runs periodically under Cloud Scheduler with transactional precondition guards.
 */
export const evaluateVotingEventLifecycles = onSchedule("every 1 minutes", async () => {
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
        if (!freshSnap.exists || freshSnap.data()?.status !== "SCHEDULED") return;
        const organizationId = freshSnap.data()?.organizationId as string | undefined;
        if (!organizationId) return;
        const organizationSnap = await transaction.get(db.collection("organizations").doc(organizationId));
        if (!organizationSnap.exists || !["verified", "active"].includes(organizationSnap.data()?.status)) return;
        transaction.update(eventDoc.ref, {
          status: "ACTIVE",
          updatedAt: FieldValue.serverTimestamp(),
        });
        activatedCount++;
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

    console.info("Voting event lifecycle evaluation completed.", {
      activatedCount,
      closedCount,
    });
  } catch (error) {
    console.error("Failed to evaluate voting event lifecycles.", error);
    throw error;
  }
});

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { requireActiveMembership } from "../utils/authorization";
import { countEligibleVoters } from "../results/tally";

export const getEventMonitoring = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required.");
  const eventId = typeof request.data?.eventId === "string" ? request.data.eventId.trim() : "";
  if (!eventId) throw new HttpsError("invalid-argument", "Valid eventId is required.");

  const db = getFirestore();
  const eventSnap = await db.collection("votingEvents").doc(eventId).get();
  if (!eventSnap.exists) throw new HttpsError("not-found", "Voting event not found.");
  const event = eventSnap.data()!;
  const organizationId = event.organizationId as string;
  await requireActiveMembership(db, organizationId, uid, ["owner", "admin"]);
  const organization = await db.collection("organizations").doc(organizationId).get();
  if (!organization.exists || !["verified", "active"].includes(organization.data()?.status)) {
    throw new HttpsError("failed-precondition", "The organization is not currently authorized to manage voting events.");
  }
  if (event.status !== "ACTIVE" && event.status !== "SCHEDULED") {
    throw new HttpsError("failed-precondition", "Live monitoring is available for scheduled or active events.");
  }

  const [eligibleCount, participation] = await Promise.all([
    countEligibleVoters(db, organizationId, event),
    db.collection("participation")
      .where("organizationId", "==", organizationId)
      .where("votingEventId", "==", eventId)
      .get(),
  ]);
  const participationCount = participation.size;
  return {
    eventId,
    status: event.status,
    eligibleCount,
    participationCount,
    turnoutPercent: eligibleCount === 0 ? 0 : Math.round((participationCount / eligibleCount) * 10000) / 100,
    refreshedAt: new Date().toISOString(),
  };
});

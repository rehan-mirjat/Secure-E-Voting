import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { requireActiveMembership } from "../utils/authorization";
import { calculateEventResults } from "../results/tally";

export const calculateResults = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required.");

  const eventId = typeof request.data?.eventId === "string" ? request.data.eventId.trim() : "";
  if (!eventId) throw new HttpsError("invalid-argument", "Valid eventId is required.");

  const db = getFirestore();
  const eventSnap = await db.collection("votingEvents").doc(eventId).get();
  if (!eventSnap.exists) throw new HttpsError("not-found", "Voting event not found.");
  const organizationId = eventSnap.data()?.organizationId as string;
  if (!organizationId) throw new HttpsError("failed-precondition", "Event has no organization.");

  await requireActiveMembership(db, organizationId, uid, ["owner", "admin"]);
  const organization = await db.collection("organizations").doc(organizationId).get();
  if (!organization.exists || !["verified", "active"].includes(organization.data()?.status)) {
    throw new HttpsError("failed-precondition", "The organization is not currently authorized to manage voting events.");
  }
  try {
    const results = await calculateEventResults(db, eventId, uid);
    await db.collection("auditLogs").add({
      organizationId,
      actorUid: uid,
      action: "CALCULATE_RESULTS",
      resourceType: "votingEvent",
      resourceId: eventId,
      metadata: { totalVotes: results.totalVotes, eligibleCount: results.eligibleCount },
      timestamp: FieldValue.serverTimestamp(),
    });
    return { status: "success", ...results };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if ((error as Error).message === "NOT_FOUND") throw new HttpsError("not-found", "Voting event not found.");
    if ((error as Error).message === "NOT_CLOSED") throw new HttpsError("failed-precondition", "Results are available after the event closes.");
    throw new HttpsError("internal", "Could not calculate results.");
  }
});

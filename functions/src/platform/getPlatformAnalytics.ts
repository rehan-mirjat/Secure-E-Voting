import { getFirestore, Query } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

async function count(query: Query): Promise<number> {
  const result = await query.count().get();
  return result.data().count;
}

/** Returns platform-wide aggregate counts without exposing ballots or user records. */
export const getPlatformAnalytics = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.auth.token.platformAdmin !== true) {
    throw new HttpsError("permission-denied", "Platform administrator access required.");
  }

  const db = getFirestore();
  const organizations = db.collection("organizations");
  const members = db.collection("organizationMembers");
  const events = db.collection("votingEvents");
  const reports = db.collection("platformReports");

  const [
    userCount,
    organizationCount,
    pendingOrganizations,
    activeOrganizations,
    suspendedOrganizations,
    memberCount,
    activeMemberCount,
    eventCount,
    activeEvents,
    pendingReports,
  ] = await Promise.all([
    count(db.collection("users")),
    count(organizations),
    count(organizations.where("status", "==", "pending")),
    count(organizations.where("status", "in", ["active", "verified"])),
    count(organizations.where("status", "==", "suspended")),
    count(members),
    count(members.where("status", "==", "active")),
    count(events),
    count(events.where("status", "in", ["ACTIVE", "active"])),
    count(reports.where("status", "==", "pending")),
  ]);

  return {
    status: "success",
    generatedAt: new Date().toISOString(),
    users: userCount,
    organizations: organizationCount,
    pendingOrganizations,
    activeOrganizations,
    suspendedOrganizations,
    members: memberCount,
    activeMembers: activeMemberCount,
    votingEvents: eventCount,
    activeVotingEvents: activeEvents,
    pendingReports,
  };
});

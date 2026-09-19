import { HttpsError } from "firebase-functions/v2/https";
import { Transaction, Firestore } from "firebase-admin/firestore";

export interface EligibilityCheckRequest {
  organizationId: string;
  eventId: string;
  userId: string;
}

/**
 * Server-authoritative voter eligibility resolution engine.
 * Evaluates live membership status and event eligibility rules dynamically.
 * Super Admins DO NOT bypass voter eligibility.
 */
export async function checkVoterEligibility(
  transaction: Transaction,
  db: Firestore,
  req: EligibilityCheckRequest
): Promise<boolean> {
  const { organizationId, eventId, userId } = req;

  if (!organizationId || !eventId || !userId) {
    throw new HttpsError("invalid-argument", "organizationId, eventId, and userId are required for eligibility check.");
  }

  // 1. Fetch organization membership record
  const memberRef = db.collection("organizationMembers").doc(`${organizationId}_${userId}`);
  const memberSnap = await transaction.get(memberRef);

  if (!memberSnap.exists || memberSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You do not have an active membership in this organization.");
  }

  const memberData = memberSnap.data()!;

  // 2. Fetch target voting event
  const eventRef = db.collection("votingEvents").doc(eventId);
  const eventSnap = await transaction.get(eventRef);

  if (!eventSnap.exists) {
    throw new HttpsError("not-found", "Target voting event not found.");
  }

  const eventData = eventSnap.data()!;
  if (eventData.organizationId !== organizationId) {
    throw new HttpsError("permission-denied", "Voting event belongs to a different organization.");
  }

  const eligibilityType = eventData.eligibilityType;

  // 3. Evaluate Live Eligibility Rules
  if (eligibilityType === "ALL_MEMBERS") {
    return true; // Any active member in organizationId is eligible
  }

  if (eligibilityType === "SELECTED_DEPARTMENTS") {
    const memberDeptId = memberData.departmentId;
    if (!memberDeptId) {
      throw new HttpsError("permission-denied", "You are not assigned to an eligible department for this event.");
    }

    const eligibleDepts: string[] = Array.isArray(eventData.eligibilityDepartmentIds)
      ? eventData.eligibilityDepartmentIds
      : [];

    if (!eligibleDepts.includes(memberDeptId)) {
      throw new HttpsError("permission-denied", "Your department is not eligible for this voting event.");
    }

    return true;
  }

  if (eligibilityType === "SELECTED_MEMBERS") {
    const eligibleUsers: string[] = Array.isArray(eventData.eligibilityUserIds)
      ? eventData.eligibilityUserIds
      : [];

    if (!eligibleUsers.includes(userId)) {
      throw new HttpsError("permission-denied", "You are not on the eligible voters list for this event.");
    }

    return true;
  }

  throw new HttpsError("invalid-argument", `Unsupported eligibilityType '${eligibilityType}'.`);
}

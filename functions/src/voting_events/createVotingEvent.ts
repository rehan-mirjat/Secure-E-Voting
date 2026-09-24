import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

export const createVotingEvent = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting: Reject any unapproved keys
  const allowedKeys = [
    "organizationId", "title", "description", "votingType",
    "eligibilityType", "eligibilityDepartmentIds", "eligibilityUserIds",
    "startAt", "endAt"
  ];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter: '${key}'`);
    }
  }

  const {
    organizationId, title, description, votingType,
    eligibilityType, eligibilityDepartmentIds, eligibilityUserIds,
    startAt, endAt
  } = data;

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!title || typeof title !== "string" || title.trim().length < 3 || title.trim().length > 100) {
    throw new HttpsError("invalid-argument", "Title must be between 3 and 100 characters.");
  }

  const cleanDescription = description && typeof description === "string" ? description.trim() : "";
  if (cleanDescription.length > 1000) {
    throw new HttpsError("invalid-argument", "Description cannot exceed 1000 characters.");
  }

  if (!["CANDIDATE_ELECTION", "SINGLE_CHOICE_POLL", "YES_NO_POLL"].includes(votingType)) {
    throw new HttpsError("invalid-argument", "Invalid votingType.");
  }

  if (!["ALL_MEMBERS", "SELECTED_MEMBERS", "SELECTED_DEPARTMENTS"].includes(eligibilityType)) {
    throw new HttpsError("invalid-argument", "Invalid eligibilityType.");
  }

  if (!startAt || !endAt) {
    throw new HttpsError("invalid-argument", "startAt and endAt timestamps are required.");
  }

  const startMillis = new Date(startAt).getTime();
  const endMillis = new Date(endAt).getTime();

  if (isNaN(startMillis) || isNaN(endMillis)) {
    throw new HttpsError("invalid-argument", "Invalid startAt or endAt timestamp format.");
  }

  const trustedNow = Timestamp.now().toMillis();

  // startAt >= trustedNow - 60s
  if (startMillis < trustedNow - 60000) {
    throw new HttpsError("invalid-argument", "startAt cannot be in the past.");
  }

  // endAt > trustedNow
  if (endMillis <= trustedNow) {
    throw new HttpsError("invalid-argument", "endAt must be in the future.");
  }

  // endAt - startAt >= 5 mins (300,000 ms)
  if (endMillis - startMillis < 300000) {
    throw new HttpsError("invalid-argument", "Voting window (endAt - startAt) must be at least 5 minutes.");
  }

  const db = getFirestore();

  // Validate Caller Membership & Role
  const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
  const callerMemberSnap = await callerMemberRef.get();

  if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You are not an active member of this organization.");
  }

  const callerRole = callerMemberSnap.data()?.role;
  if (callerRole !== "owner" && callerRole !== "admin") {
    throw new HttpsError("permission-denied", "Only Organization Owners or Admins can create voting events.");
  }

  // Validate Eligibility References & Deterministic Arrays
  if (eligibilityType === "ALL_MEMBERS") {
    if (Array.isArray(eligibilityDepartmentIds) && eligibilityDepartmentIds.length > 0) {
      throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be empty when eligibilityType is ALL_MEMBERS.");
    }
    if (Array.isArray(eligibilityUserIds) && eligibilityUserIds.length > 0) {
      throw new HttpsError("invalid-argument", "eligibilityUserIds must be empty when eligibilityType is ALL_MEMBERS.");
    }
  }

  if (eligibilityType === "SELECTED_DEPARTMENTS") {
    if (Array.isArray(eligibilityUserIds) && eligibilityUserIds.length > 0) {
      throw new HttpsError("invalid-argument", "eligibilityUserIds must be empty when eligibilityType is SELECTED_DEPARTMENTS.");
    }
    // DRAFT creation logic: Do NOT enforce array > 0 length at creation.
    // An admin must be able to create a DRAFT event even if 0 departments currently exist.
    if (!Array.isArray(eligibilityDepartmentIds)) {
      throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be an array for SELECTED_DEPARTMENTS.");
    }
    for (const deptId of eligibilityDepartmentIds) {
      const deptSnap = await db.collection("departments").doc(deptId).get();
      if (!deptSnap.exists || deptSnap.data()?.organizationId !== organizationId) {
        throw new HttpsError("invalid-argument", `Department '${deptId}' does not exist in this organization.`);
      }
    }
  }

  if (eligibilityType === "SELECTED_MEMBERS") {
    if (Array.isArray(eligibilityDepartmentIds) && eligibilityDepartmentIds.length > 0) {
      throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be empty when eligibilityType is SELECTED_MEMBERS.");
    }
    // DRAFT creation logic: Do NOT enforce array > 0 length at creation.
    // An admin must be able to create a DRAFT event even if 0 members currently exist.
    if (!Array.isArray(eligibilityUserIds)) {
      throw new HttpsError("invalid-argument", "eligibilityUserIds must be an array for SELECTED_MEMBERS.");
    }
    for (const targetUid of eligibilityUserIds) {
      const targetMemberSnap = await db.collection("organizationMembers").doc(`${organizationId}_${targetUid}`).get();
      if (!targetMemberSnap.exists || targetMemberSnap.data()?.status !== "active") {
        throw new HttpsError("invalid-argument", `User '${targetUid}' is not an active member in this organization.`);
      }
    }
  }

  const eventRef = db.collection("votingEvents").doc();
  const eventId = eventRef.id;

  try {
    await db.runTransaction(async (transaction) => {
      transaction.set(eventRef, {
        id: eventId,
        organizationId: organizationId,
        title: title.trim(),
        description: cleanDescription,
        votingType: votingType,
        privacyMode: "ANONYMOUS", // Forced V1 Privacy Contract
        maxSelections: 1,        // Forced V1 Single Selection Contract
        eligibilityType: eligibilityType,
        eligibilityDepartmentIds: eligibilityType === "SELECTED_DEPARTMENTS" ? eligibilityDepartmentIds : [],
        eligibilityUserIds: eligibilityType === "SELECTED_MEMBERS" ? eligibilityUserIds : [],
        status: "DRAFT",
        startAt: Timestamp.fromMillis(startMillis),
        endAt: Timestamp.fromMillis(endMillis),
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        closedAt: null,
        closedBy: null,
        cancelledAt: null,
        cancelledBy: null,
        archivedAt: null,
        archivedBy: null,
      });

      // Step 2 Integration Extension: Auto-provision YES/NO options if YES_NO_POLL
      if (votingType === "YES_NO_POLL") {
        const yesOptRef = db.collection("pollOptions").doc(`${eventId}_YES`);
        const noOptRef = db.collection("pollOptions").doc(`${eventId}_NO`);

        transaction.set(yesOptRef, {
          id: `${eventId}_YES`,
          organizationId: organizationId,
          votingEventId: eventId,
          label: "Yes",
          description: "",
          sortOrder: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.set(noOptRef, {
          id: `${eventId}_NO`,
          organizationId: organizationId,
          votingEventId: eventId,
          label: "No",
          description: "",
          sortOrder: 2,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "CREATE_VOTING_EVENT",
        resourceType: "votingEvent",
        resourceId: eventId,
        metadata: {
          title: title.trim(),
          votingType: votingType,
          privacyMode: "ANONYMOUS",
          eligibilityType: eligibilityType,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success", eventId: eventId };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to create voting event.", error);
  }
});

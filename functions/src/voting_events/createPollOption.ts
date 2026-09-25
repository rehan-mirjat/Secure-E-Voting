import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const createPollOption = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting
  const allowedKeys = ["organizationId", "votingEventId", "label", "description", "sortOrder"];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter '${key}' in createPollOption payload.`);
    }
  }

  const { organizationId, votingEventId, label, description, sortOrder = 0 } = data;

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  if (!votingEventId || typeof votingEventId !== "string" || votingEventId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid votingEventId is required.");
  }

  if (!label || typeof label !== "string" || label.trim().length < 1 || label.trim().length > 100) {
    throw new HttpsError("invalid-argument", "Poll option label must be between 1 and 100 characters.");
  }

  const cleanDescription = description && typeof description === "string" ? description.trim() : "";
  if (cleanDescription.length > 500) {
    throw new HttpsError("invalid-argument", "Description cannot exceed 500 characters.");
  }

  const parsedSortOrder = Number(sortOrder);
  if (isNaN(parsedSortOrder) || !Number.isInteger(parsedSortOrder) || parsedSortOrder < 0) {
    throw new HttpsError("invalid-argument", "sortOrder must be a non-negative integer.");
  }

  const db = getFirestore();

  try {
    const optionRef = db.collection("pollOptions").doc();
    const optionId = optionRef.id;

    await db.runTransaction(async (transaction) => {
      // 1. Verify Parent Event
      const eventRef = db.collection("votingEvents").doc(votingEventId);
      const eventSnap = await transaction.get(eventRef);

      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Target voting event not found.");
      }

      const eventData = eventSnap.data()!;
      if (eventData.organizationId !== organizationId) {
        throw new HttpsError("permission-denied", "Voting event belongs to a different organization.");
      }

      if (eventData.status !== "DRAFT") {
        throw new HttpsError("failed-precondition", `Poll options can be created ONLY for DRAFT events. Current status: '${eventData.status}'`);
      }

      if (eventData.votingType !== "SINGLE_CHOICE_POLL") {
        throw new HttpsError("failed-precondition", `Poll options can be created ONLY for SINGLE_CHOICE_POLL events. Event type: '${eventData.votingType}'`);
      }

      // 2. Validate Caller Role
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active" ||
          callerSnap.data()?.organizationId !== organizationId || callerSnap.data()?.userId !== uid) {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can create poll options.");
      }

      // 3. Create Poll Option Document
      transaction.set(optionRef, {
        id: optionId,
        organizationId: organizationId,
        votingEventId: votingEventId,
        label: label.trim(),
        description: cleanDescription,
        sortOrder: parsedSortOrder,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 4. Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "CREATE_POLL_OPTION",
        resourceType: "pollOption",
        resourceId: optionId,
        metadata: {
          label: label.trim(),
          votingEventId: votingEventId,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success", optionId: optionId };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to create poll option.", error);
  }
});

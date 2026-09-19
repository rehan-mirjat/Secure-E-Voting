import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const updatePollOption = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting
  const allowedKeys = ["optionId", "label", "description", "sortOrder"];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter '${key}' in updatePollOption payload.`);
    }
  }

  const { optionId, label, description, sortOrder } = data;

  if (!optionId || typeof optionId !== "string" || optionId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid optionId is required.");
  }

  const db = getFirestore();
  const optionRef = db.collection("pollOptions").doc(optionId);

  try {
    await db.runTransaction(async (transaction) => {
      const optSnap = await transaction.get(optionRef);
      if (!optSnap.exists) {
        throw new HttpsError("not-found", "Poll option not found.");
      }

      const optData = optSnap.data()!;
      const organizationId = optData.organizationId;
      const votingEventId = optData.votingEventId;

      // YES_NO_POLL Generated Option Protection: Rejects modification of generated options
      if (optionId.endsWith("_YES") || optionId.endsWith("_NO")) {
        throw new HttpsError("failed-precondition", "Generated YES/NO poll options cannot be modified.");
      }

      // Validate Parent Event Status
      const eventSnap = await transaction.get(db.collection("votingEvents").doc(votingEventId));
      if (!eventSnap.exists) {
        throw new HttpsError("not-found", "Voting event not found.");
      }

      const eventStatus = eventSnap.data()?.status;
      if (eventStatus !== "DRAFT") {
        throw new HttpsError("failed-precondition", `Poll options can be updated ONLY in DRAFT events. Current status: '${eventStatus}'`);
      }

      // Validate Caller Role
      const callerRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerSnap = await transaction.get(callerRef);

      if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const role = callerSnap.data()?.role;
      if (role !== "owner" && role !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can update poll options.");
      }

      const updates: any = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (label !== undefined) {
        if (typeof label !== "string" || label.trim().length < 1 || label.trim().length > 100) {
          throw new HttpsError("invalid-argument", "Poll option label must be between 1 and 100 characters.");
        }
        updates.label = label.trim();
      }

      if (description !== undefined) {
        const cleanDesc = typeof description === "string" ? description.trim() : "";
        if (cleanDesc.length > 500) {
          throw new HttpsError("invalid-argument", "Description cannot exceed 500 characters.");
        }
        updates.description = cleanDesc;
      }

      if (sortOrder !== undefined) {
        const parsedSortOrder = Number(sortOrder);
        if (isNaN(parsedSortOrder) || !Number.isInteger(parsedSortOrder) || parsedSortOrder < 0) {
          throw new HttpsError("invalid-argument", "sortOrder must be a non-negative integer.");
        }
        updates.sortOrder = parsedSortOrder;
      }

      transaction.update(optionRef, updates);

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "UPDATE_POLL_OPTION",
        resourceType: "pollOption",
        resourceId: optionId,
        metadata: {
          label: updates.label || optData.label,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update poll option.", error);
  }
});

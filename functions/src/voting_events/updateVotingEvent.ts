import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

export const updateVotingEvent = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const data = request.data || {};

  // Strict Schema Whitelisting: Reject any unapproved keys
  const allowedKeys = [
    "eventId", "title", "description",
    "eligibilityType", "eligibilityDepartmentIds", "eligibilityUserIds",
    "startAt", "endAt"
  ];
  for (const key of Object.keys(data)) {
    if (!allowedKeys.includes(key)) {
      throw new HttpsError("invalid-argument", `Unpermitted parameter: '${key}'`);
    }
  }

  const {
    eventId, title, description,
    eligibilityType, eligibilityDepartmentIds, eligibilityUserIds,
    startAt, endAt
  } = data;

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

      // 1. Strict Immutability Guard: Permitted ONLY when status == "DRAFT"
      if (currentStatus !== "DRAFT") {
        throw new HttpsError(
          "failed-precondition",
          `Voting event in status '${currentStatus}' is strictly immutable and cannot be updated.`
        );
      }

      // 2. Validate Caller Membership & Role
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerMemberSnap = await transaction.get(callerMemberRef);

      if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerMemberSnap.data()?.role;
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can update voting events.");
      }

      const updates: any = {
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (title !== undefined) {
        if (typeof title !== "string" || title.trim().length < 3 || title.trim().length > 100) {
          throw new HttpsError("invalid-argument", "Title must be between 3 and 100 characters.");
        }
        updates.title = title.trim();
      }

      if (description !== undefined) {
        const cleanDesc = typeof description === "string" ? description.trim() : "";
        if (cleanDesc.length > 1000) {
          throw new HttpsError("invalid-argument", "Description cannot exceed 1000 characters.");
        }
        updates.description = cleanDesc;
      }

      const trustedNow = Timestamp.now().toMillis();
      let effectiveStartMillis = eventData.startAt ? eventData.startAt.toMillis() : trustedNow;
      let effectiveEndMillis = eventData.endAt ? eventData.endAt.toMillis() : trustedNow + 300000;

      if (startAt !== undefined) {
        const parsedStart = new Date(startAt).getTime();
        if (isNaN(parsedStart)) throw new HttpsError("invalid-argument", "Invalid startAt timestamp.");
        if (parsedStart < trustedNow - 60000) {
          throw new HttpsError("invalid-argument", "startAt cannot be in the past.");
        }
        effectiveStartMillis = parsedStart;
        updates.startAt = Timestamp.fromMillis(parsedStart);
      }

      if (endAt !== undefined) {
        const parsedEnd = new Date(endAt).getTime();
        if (isNaN(parsedEnd)) throw new HttpsError("invalid-argument", "Invalid endAt timestamp.");
        if (parsedEnd <= trustedNow) {
          throw new HttpsError("invalid-argument", "endAt must be in the future.");
        }
        effectiveEndMillis = parsedEnd;
        updates.endAt = Timestamp.fromMillis(parsedEnd);
      }

      if (effectiveEndMillis - effectiveStartMillis < 300000) {
        throw new HttpsError("invalid-argument", "Voting window (endAt - startAt) must be at least 5 minutes.");
      }

      if (eligibilityType !== undefined) {
        if (!["ALL_MEMBERS", "SELECTED_MEMBERS", "SELECTED_DEPARTMENTS"].includes(eligibilityType)) {
          throw new HttpsError("invalid-argument", "Invalid eligibilityType.");
        }
        updates.eligibilityType = eligibilityType;

        if (eligibilityType === "ALL_MEMBERS") {
          if (Array.isArray(eligibilityDepartmentIds) && eligibilityDepartmentIds.length > 0) {
            throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be empty when eligibilityType is ALL_MEMBERS.");
          }
          if (Array.isArray(eligibilityUserIds) && eligibilityUserIds.length > 0) {
            throw new HttpsError("invalid-argument", "eligibilityUserIds must be empty when eligibilityType is ALL_MEMBERS.");
          }
          updates.eligibilityDepartmentIds = [];
          updates.eligibilityUserIds = [];
        } else if (eligibilityType === "SELECTED_DEPARTMENTS") {
          if (Array.isArray(eligibilityUserIds) && eligibilityUserIds.length > 0) {
            throw new HttpsError("invalid-argument", "eligibilityUserIds must be empty when eligibilityType is SELECTED_DEPARTMENTS.");
          }
          if (!Array.isArray(eligibilityDepartmentIds)) {
            throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be an array for SELECTED_DEPARTMENTS.");
          }
          for (const deptId of eligibilityDepartmentIds) {
            const deptSnap = await transaction.get(db.collection("departments").doc(deptId));
            if (!deptSnap.exists || deptSnap.data()?.organizationId !== organizationId) {
              throw new HttpsError("invalid-argument", `Department '${deptId}' does not exist in this organization.`);
            }
          }
          updates.eligibilityDepartmentIds = eligibilityDepartmentIds;
          updates.eligibilityUserIds = [];
        } else if (eligibilityType === "SELECTED_MEMBERS") {
          if (Array.isArray(eligibilityDepartmentIds) && eligibilityDepartmentIds.length > 0) {
            throw new HttpsError("invalid-argument", "eligibilityDepartmentIds must be empty when eligibilityType is SELECTED_MEMBERS.");
          }
          if (!Array.isArray(eligibilityUserIds)) {
            throw new HttpsError("invalid-argument", "eligibilityUserIds must be an array for SELECTED_MEMBERS.");
          }
          for (const targetUid of eligibilityUserIds) {
            const targetMemberSnap = await transaction.get(db.collection("organizationMembers").doc(`${organizationId}_${targetUid}`));
            if (!targetMemberSnap.exists || targetMemberSnap.data()?.status !== "active") {
              throw new HttpsError("invalid-argument", `User '${targetUid}' is not an active member in this organization.`);
            }
          }
          updates.eligibilityUserIds = eligibilityUserIds;
          updates.eligibilityDepartmentIds = [];
        }
      }

      transaction.update(eventRef, updates);

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "UPDATE_VOTING_EVENT",
        resourceType: "votingEvent",
        resourceId: eventId,
        metadata: {
          title: updates.title || eventData.title,
          previousStatus: currentStatus,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update voting event.", error);
  }
});

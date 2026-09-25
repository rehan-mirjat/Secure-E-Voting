import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

export const publishVotingEvent = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { eventId } = request.data || {};

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

      const organizationSnap = await transaction.get(db.collection("organizations").doc(organizationId));
      if (!organizationSnap.exists || !["verified", "active"].includes(organizationSnap.data()?.status)) {
        throw new HttpsError("failed-precondition", "The organization must be verified before publishing voting events.");
      }

      if (currentStatus !== "DRAFT") {
        throw new HttpsError("failed-precondition", `Only DRAFT events can be published. Current status: '${currentStatus}'`);
      }

      // Validate Caller Membership & Role
      const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const callerMemberSnap = await transaction.get(callerMemberRef);

      if (!callerMemberSnap.exists || callerMemberSnap.data()?.status !== "active" ||
          callerMemberSnap.data()?.organizationId !== organizationId || callerMemberSnap.data()?.userId !== uid) {
        throw new HttpsError("permission-denied", "You are not an active member of this organization.");
      }

      const callerRole = callerMemberSnap.data()?.role;
      if (callerRole !== "owner" && callerRole !== "admin") {
        throw new HttpsError("permission-denied", "Only Organization Owners or Admins can publish voting events.");
      }

      // Re-validate Eligibility Configuration during Publish
      const eligibilityType = eventData.eligibilityType;
      if (eligibilityType === "SELECTED_DEPARTMENTS") {
        const deptIds: string[] = Array.isArray(eventData.eligibilityDepartmentIds) ? eventData.eligibilityDepartmentIds : [];
        if (deptIds.length === 0) {
          throw new HttpsError("failed-precondition", "SELECTED_DEPARTMENTS requires at least one eligible department.");
        }
        for (const deptId of deptIds) {
          const deptSnap = await transaction.get(db.collection("departments").doc(deptId));
          if (!deptSnap.exists || deptSnap.data()?.organizationId !== organizationId) {
            throw new HttpsError("failed-precondition", `Referenced department '${deptId}' no longer exists in this organization.`);
          }
        }
      } else if (eligibilityType === "SELECTED_MEMBERS") {
        const userIds: string[] = Array.isArray(eventData.eligibilityUserIds) ? eventData.eligibilityUserIds : [];
        if (userIds.length === 0) {
          throw new HttpsError("failed-precondition", "SELECTED_MEMBERS requires at least one eligible member.");
        }
      }
      // Candidate / Poll Option Completeness & Ownership Re-validation
      const votingType = eventData.votingType;
      if (votingType === "CANDIDATE_ELECTION") {
        const candSnap = await transaction.get(
          db.collection("candidates")
            .where("organizationId", "==", organizationId)
            .where("votingEventId", "==", eventId)
        );

        let validCandCount = 0;
        for (const candDoc of candSnap.docs) {
          const candData = candDoc.data();
          const hasValidName = candData.name && typeof candData.name === "string" && candData.name.trim().length >= 3;
          const hasValidOrg = candData.organizationId === organizationId && candData.votingEventId === eventId;
          const hasConsistentPhoto = (candData.photoUrl === null && candData.photoPath === null) || (candData.photoUrl !== null && candData.photoPath !== null);

          if (hasValidName && hasValidOrg && hasConsistentPhoto) {
            validCandCount++;
          }
        }

        if (validCandCount < 2) {
          throw new HttpsError(
            "failed-precondition",
            `A candidate election requires at least 2 valid candidates before publishing. Current valid count: ${validCandCount}`
          );
        }
      } else if (votingType === "SINGLE_CHOICE_POLL") {
        const optSnap = await transaction.get(
          db.collection("pollOptions")
            .where("organizationId", "==", organizationId)
            .where("votingEventId", "==", eventId)
        );

        let validOptCount = 0;
        for (const optDoc of optSnap.docs) {
          const optData = optDoc.data();
          const hasValidLabel = optData.label && typeof optData.label === "string" && optData.label.trim().length >= 1;
          const hasValidOrg = optData.organizationId === organizationId && optData.votingEventId === eventId;
          const hasValidOrder = typeof optData.sortOrder === "number" && optData.sortOrder >= 0;

          if (hasValidLabel && hasValidOrg && hasValidOrder) {
            validOptCount++;
          }
        }

        if (validOptCount < 2) {
          throw new HttpsError(
            "failed-precondition",
            `A single-choice poll requires at least 2 valid poll options before publishing. Current valid count: ${validOptCount}`
          );
        }
      }
      const trustedNow = Timestamp.now().toMillis();
      const startMillis = eventData.startAt ? eventData.startAt.toMillis() : trustedNow;
      const endMillis = eventData.endAt ? eventData.endAt.toMillis() : trustedNow + 300000;

      if (endMillis <= trustedNow) {
        throw new HttpsError("invalid-argument", "Cannot publish event whose endAt has already passed.");
      }

      // Determine next status: SCHEDULED if startAt > trustedNow, ACTIVE if startAt <= trustedNow
      const nextStatus = startMillis > trustedNow ? "SCHEDULED" : "ACTIVE";

      transaction.update(eventRef, {
        status: nextStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit Log
      const auditRef = db.collection("auditLogs").doc();
      transaction.set(auditRef, {
        organizationId: organizationId,
        actorUid: uid,
        action: "PUBLISH_VOTING_EVENT",
        resourceType: "votingEvent",
        resourceId: eventId,
        metadata: {
          previousStatus: "DRAFT",
          newStatus: nextStatus,
          startAt: eventData.startAt,
          endAt: eventData.endAt,
        },
        timestamp: FieldValue.serverTimestamp(),
      });
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to publish voting event.", error);
  }
});

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

type ReviewAction = "VERIFY" | "REJECT" | "SUSPEND" | "REACTIVATE";

export const reviewOrganization = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required.");
  if (request.auth?.token.platformAdmin !== true) throw new HttpsError("permission-denied", "Platform administrator access required.");

  const organizationId = typeof request.data?.organizationId === "string" ? request.data.organizationId.trim() : "";
  const action = request.data?.action as ReviewAction;
  if (!organizationId || !["VERIFY", "REJECT", "SUSPEND", "REACTIVATE"].includes(action)) {
    throw new HttpsError("invalid-argument", "Organization and a valid review action are required.");
  }

  const db = getFirestore();
  const organizationRef = db.collection("organizations").doc(organizationId);
  try {
    await db.runTransaction(async (transaction) => {
      const organization = await transaction.get(organizationRef);
      if (!organization.exists) throw new HttpsError("not-found", "Organization not found.");
      const previousStatus = organization.data()?.status as string;
      const transitions: Record<ReviewAction, { from: string[]; to: string }> = {
        VERIFY: { from: ["pending"], to: "verified" },
        REJECT: { from: ["pending"], to: "rejected" },
        SUSPEND: { from: ["verified", "active"], to: "suspended" },
        REACTIVATE: { from: ["suspended"], to: "active" },
      };
      const transition = transitions[action];
      if (!transition.from.includes(previousStatus)) {
        throw new HttpsError("failed-precondition", `Cannot ${action.toLowerCase()} an organization in '${previousStatus}' status.`);
      }

      transaction.update(organizationRef, {
        status: transition.to,
        updatedAt: FieldValue.serverTimestamp(),
        ...(action === "VERIFY" ? { verifiedAt: FieldValue.serverTimestamp() } : {}),
        ...(action === "REJECT" ? { rejectedAt: FieldValue.serverTimestamp(), rejectedBy: uid } : {}),
        ...(action === "SUSPEND" ? { suspendedAt: FieldValue.serverTimestamp() } : {}),
        ...(action === "REACTIVATE" ? { suspendedAt: null } : {}),
      });
      transaction.set(db.collection("platformAuditLogs").doc(), {
        actorUid: uid,
        action: `ORGANIZATION_${action}`,
        organizationId,
        previousStatus,
        newStatus: transition.to,
        timestamp: FieldValue.serverTimestamp(),
      });
    });
    return { status: "success", organizationId, action };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Could not update organization verification status.");
  }
});

import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/** Removes the platform-admin custom claim without changing other custom claims. */
export const removeAdmin = onCall(async (request) => {
  const actorUid = request.auth?.uid;
  if (!actorUid) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (request.auth?.token.platformAdmin !== true) {
    throw new HttpsError("permission-denied", "Platform administrator access required.");
  }

  const targetUid = typeof request.data?.uid === "string"
    ? request.data.uid.trim()
    : "";
  if (!targetUid) throw new HttpsError("invalid-argument", "Choose a platform user.");
  if (targetUid === actorUid) {
    throw new HttpsError("failed-precondition", "You cannot remove your own platform access.");
  }

  let target;
  try {
    target = await getAuth().getUser(targetUid);
  } catch (error: any) {
    if (error?.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "The selected account no longer exists.");
    }
    console.error("removeAdmin could not find the requested account", { code: error?.code ?? "unknown" });
    throw new HttpsError("unavailable", "The account could not be checked. Try again.");
  }
  if (target.customClaims?.platformAdmin !== true) {
    throw new HttpsError("failed-precondition", "This account does not have platform administrator access.");
  }

  const claims = { ...(target.customClaims ?? {}) };
  delete claims.platformAdmin;
  await getAuth().setCustomUserClaims(targetUid, claims);
  await getFirestore().collection("platformAuditLogs").add({
    actorUid,
    action: "PLATFORM_ADMIN_ACCESS_REMOVED",
    targetUid,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { status: "success", uid: targetUid };
});

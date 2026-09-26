import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/** Lists safe joining-code metadata; the original codes and HMACs are never returned. */
export const getJoiningCodes = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");

  const organizationId = typeof request.data?.organizationId === "string"
    ? request.data.organizationId.trim()
    : "";
  if (!organizationId) {
    throw new HttpsError("invalid-argument", "A valid organizationId is required.");
  }

  const db = getFirestore();
  const member = await db.collection("organizationMembers").doc(`${organizationId}_${uid}`).get();
  const data = member.data();
  if (!member.exists || data?.status !== "active" || data.organizationId !== organizationId ||
      data.userId !== uid || (data.role !== "owner" && data.role !== "admin")) {
    throw new HttpsError("permission-denied", "Only active Organization Owners or Admins can view joining codes.");
  }

  const snapshot = await db.collection("joiningCodes")
    .where("organizationId", "==", organizationId)
    .get();
  const now = Date.now();
  const codes = snapshot.docs.map((doc) => {
    const code = doc.data();
    const expiresAt = code.expiresAt?.toDate?.() ?? null;
    const status = code.status === "active" && expiresAt && expiresAt.getTime() <= now
      ? "expired"
      : code.status ?? "unknown";
    return {
      codeId: doc.id,
      displayId: doc.id.slice(-8).toUpperCase(),
      status,
      currentUses: Number(code.currentUses ?? 0),
      maxUses: Number(code.maxUses ?? 0),
      expiresAt: expiresAt?.toISOString() ?? null,
      createdAt: code.createdAt?.toDate?.().toISOString?.() ?? null,
    };
  }).sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""));

  return { status: "success", codes };
});

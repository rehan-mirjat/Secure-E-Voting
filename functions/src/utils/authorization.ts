import { HttpsError } from "firebase-functions/v2/https";
import { Firestore } from "firebase-admin/firestore";
export function isPlatformAdmin(auth: { token?: Record<string, unknown> } | undefined): boolean {
  return auth?.token?.platformAdmin === true;
}

export async function requireActiveMembership(
  db: Firestore,
  organizationId: string,
  uid: string,
  allowedRoles?: string[]
): Promise<{ role: string }> {
  const snap = await db.collection("organizationMembers").doc(`${organizationId}_${uid}`).get();
  const data = snap.data();
  if (!snap.exists || data?.status !== "active") {
    throw new HttpsError("permission-denied", "You are not an active member of this organization.");
  }
  if (data.organizationId !== organizationId || data.userId !== uid) {
    throw new HttpsError("permission-denied", "Membership record is invalid.");
  }
  const role = data.role as string;
  if (allowedRoles && !allowedRoles.includes(role)) {
    throw new HttpsError("permission-denied", "Insufficient organization role.");
  }
  return { role };
}

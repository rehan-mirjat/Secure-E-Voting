import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

export const listOrganizationsForPlatformAdmin = onCall(async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required.");
  if (request.auth.token.platformAdmin !== true) throw new HttpsError("permission-denied", "Platform administrator access required.");
  const snapshot = await getFirestore().collection("organizations").orderBy("createdAt", "desc").limit(100).get();
  return {
    organizations: snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        name: data.name ?? "Organization",
        email: data.email ?? "",
        type: data.type ?? "",
        website: data.website ?? "",
        country: data.country ?? "",
        city: data.city ?? "",
        status: data.status ?? "pending",
        createdAt: data.createdAt?.toDate?.().toISOString?.() ?? null,
      };
    }),
  };
});

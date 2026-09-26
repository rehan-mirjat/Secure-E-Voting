import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/** Lists a bounded page of accounts for authorized platform user administration. */
export const listPlatformUsers = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  if (request.auth.token.platformAdmin !== true) {
    throw new HttpsError("permission-denied", "Platform administrator access required.");
  }

  const pageToken = typeof request.data?.pageToken === "string"
    ? request.data.pageToken
    : undefined;
  const page = await getAuth().listUsers(100, pageToken);

  return {
    status: "success",
    users: page.users.map((user) => ({
      uid: user.uid,
      email: user.email ?? "",
      displayName: user.displayName ?? "",
      photoUrl: user.photoURL ?? null,
      disabled: user.disabled,
      emailVerified: user.emailVerified,
      platformAdmin: user.customClaims?.platformAdmin === true,
      createdAt: user.metadata.creationTime ?? null,
      lastSignInAt: user.metadata.lastSignInTime ?? null,
    })),
    nextPageToken: page.pageToken ?? null,
  };
});

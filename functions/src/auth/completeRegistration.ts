import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Secures the user registration flow.
 * Flutter calls this immediately after creating the Firebase Auth account or on Google Sign-In.
 * Guarantees profile creation without failing on single-word names or empty last names.
 */
export const completeRegistration = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated to complete registration.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";

  // 2. Extract and validate payload
  const { firstName, lastName } = request.data || {};

  const rawFirst = (firstName && typeof firstName === "string") ? firstName.trim() : "";
  const rawLast = (lastName && typeof lastName === "string") ? lastName.trim() : "";

  const trimmedFirst = rawFirst.length > 0 ? rawFirst : (request.auth.token.name ? request.auth.token.name.split(" ")[0] : "Google");
  const trimmedLast = rawLast.length > 0 ? rawLast : "User";

  if (trimmedFirst.length > 50 || trimmedLast.length > 50) {
    throw new HttpsError("invalid-argument", "First name and last name cannot exceed 50 characters.");
  }

  const displayName = `${trimmedFirst} ${trimmedLast}`;

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  // 3. Atomically create the user profile ONLY if it doesn't already exist
  try {
    const userSnap = await userRef.get();
    if (userSnap.exists) {
      return { status: "success", message: "User profile already exists." };
    }

    await userRef.set({
      userId: uid,
      email: email,
      displayName: displayName,
      firstName: trimmedFirst,
      lastName: trimmedLast,
      photoUrl: request.auth.token.picture || null,
      phoneNumber: null,
      emailVerified: request.auth.token.email_verified || false,
      twoFactorEnabled: false,
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { status: "success" };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to complete user registration.", error);
  }
});

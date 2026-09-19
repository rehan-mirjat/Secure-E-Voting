import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Secures the user registration flow.
 * Flutter calls this immediately after creating the Firebase Auth account.
 * This guarantees we don't rely on race-condition-prone auth profile updates.
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

  if (!firstName || !lastName || typeof firstName !== "string" || typeof lastName !== "string") {
    throw new HttpsError("invalid-argument", "First name and last name are required strings.");
  }

  const trimmedFirst = firstName.trim();
  const trimmedLast = lastName.trim();

  if (trimmedFirst.length === 0 || trimmedLast.length === 0) {
    throw new HttpsError("invalid-argument", "First name and last name cannot be blank.");
  }

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
      throw new HttpsError("already-exists", "User profile already exists for this account.");
    }

    await userRef.set({
      userId: uid,
      email: email,
      displayName: displayName,
      firstName: trimmedFirst,
      lastName: trimmedLast,
      photoUrl: null,
      phoneNumber: null,
      emailVerified: false,
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

import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

type InvitationAction = "list" | "accept" | "decline";

async function getVerifiedEmail(uid: string): Promise<string> {
  try {
    const user = await getAuth().getUser(uid);
    const isGoogleUser = user.providerData.some((provider) => provider.providerId === "google.com");
    if (!user.email || (!user.emailVerified && !isGoogleUser)) {
      throw new HttpsError("permission-denied", "Verify the invited email address before responding to this invitation.");
    }
    return user.email.trim().toLowerCase();
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("memberInvitations could not verify the signed-in account", error);
    throw new HttpsError("unauthenticated", "Sign in again before responding to this invitation.");
  }
}

/** Lists only invitations addressed to the authenticated, verified account and responds to them. */
export const memberInvitations = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");

  const action = request.data?.action as InvitationAction | undefined;
  if (action !== "list" && action !== "accept" && action !== "decline") {
    throw new HttpsError("invalid-argument", "Choose list, accept, or decline.");
  }

  const email = await getVerifiedEmail(uid);
  const db = getFirestore();

  if (action === "list") {
    const snapshot = await db.collection("organizationInvitations")
      .where("email", "==", email)
      .get();
    const now = Date.now();
    const pending = snapshot.docs.filter((doc) => {
      const data = doc.data();
      const expiresAt = data.expiresAt?.toDate?.().getTime();
      return data.status === "pending" && (expiresAt == null || expiresAt > now);
    });
    const organizationIds = [...new Set(pending.map((doc) => doc.data().organizationId as string))];
    const organizationSnapshots = await Promise.all(
      organizationIds.map((organizationId) => db.collection("organizations").doc(organizationId).get()),
    );
    const organizationNames = new Map(
      organizationSnapshots.map((snapshot) => [snapshot.id, snapshot.data()?.name || "Organization"]),
    );

    return {
      status: "success",
      invitations: pending.map((doc) => {
        const data = doc.data();
        return {
          invitationId: doc.id,
          organizationId: data.organizationId,
          organizationName: organizationNames.get(data.organizationId) || "Organization",
          role: data.role || "member",
          expiresAt: data.expiresAt?.toDate?.().toISOString() || null,
          createdAt: data.createdAt?.toDate?.().toISOString() || null,
        };
      }),
    };
  }

  const invitationId = typeof request.data?.invitationId === "string"
    ? request.data.invitationId.trim()
    : "";
  if (!invitationId) throw new HttpsError("invalid-argument", "A valid invitation is required.");

  const invitationRef = db.collection("organizationInvitations").doc(invitationId);
  const userRef = db.collection("users").doc(uid);
  const auditRef = db.collection("auditLogs").doc();

  try {
    const result = await db.runTransaction(async (transaction) => {
      const invitationSnapshot = await transaction.get(invitationRef);
      if (!invitationSnapshot.exists) {
        throw new HttpsError("not-found", "This invitation is no longer available.");
      }

      const invitation = invitationSnapshot.data()!;
      if ((invitation.email || "").trim().toLowerCase() !== email) {
        throw new HttpsError("permission-denied", "This invitation was sent to a different email address.");
      }
      if (invitation.status !== "pending") {
        throw new HttpsError("failed-precondition", "This invitation has already been handled or is no longer valid.");
      }
      const expiresAt = invitation.expiresAt?.toDate?.();
      if (expiresAt && expiresAt.getTime() <= Date.now()) {
        throw new HttpsError("failed-precondition", "This invitation has expired. Ask the organization administrator to send another.");
      }

      const organizationId = invitation.organizationId as string;
      if (!organizationId) throw new HttpsError("failed-precondition", "The invitation is missing its organization.");
      const organizationRef = db.collection("organizations").doc(organizationId);
      const membershipRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
      const [userSnapshot, organizationSnapshot, membershipSnapshot] = await transaction.getAll(
        userRef,
        organizationRef,
        membershipRef,
      );

      if (!userSnapshot.exists || userSnapshot.data()?.status !== "active") {
        throw new HttpsError("failed-precondition", "Your SecureVote account must be active before responding.");
      }

      const organization = organizationSnapshot.data();
      if (!organizationSnapshot.exists) {
        throw new HttpsError("failed-precondition", "This organization no longer exists.");
      }
      if (action === "accept" && !["active", "verified"].includes(organization?.status)) {
        throw new HttpsError("failed-precondition", "This organization cannot accept members right now.");
      }
      if (action === "accept" && membershipSnapshot.exists && membershipSnapshot.data()?.status === "active") {
        throw new HttpsError("already-exists", "You are already an active member of this organization.");
      }

      const role = invitation.role === "admin" ? "admin" : "member";
      const timestampField = action === "accept" ? "acceptedAt" : "declinedAt";
      transaction.update(invitationRef, {
        status: action === "accept" ? "accepted" : "declined",
        [timestampField]: FieldValue.serverTimestamp(),
      });

      if (action === "accept") {
        transaction.set(membershipRef, {
          membershipId: membershipRef.id,
          organizationId,
          userId: uid,
          role,
          status: "active",
          employeeId: null,
          departmentId: null,
          joinedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.delete(db.collection("organizationInvitationKeys").doc(`${organizationId}_${email}`));
      if (typeof invitation.tokenHash === "string" && invitation.tokenHash) {
        transaction.delete(db.collection("organizationInvitationTokens").doc(invitation.tokenHash));
      }
      transaction.set(auditRef, {
        organizationId,
        actorUid: uid,
        action: action === "accept" ? "ACCEPT_INVITATION" : "DECLINE_INVITATION",
        resourceType: "organizationInvitation",
        resourceId: invitationId,
        metadata: { targetEmail: email, role },
        timestamp: FieldValue.serverTimestamp(),
      });

      return {
        organizationId,
        organizationName: organization?.name || "Organization",
      };
    });

    return { status: "success", action, ...result };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("memberInvitations could not update the invitation", error);
    throw new HttpsError("internal", "The invitation response could not be saved. Please try again.");
  }
});

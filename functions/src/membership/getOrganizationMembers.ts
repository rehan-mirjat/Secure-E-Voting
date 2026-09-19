import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

export const getOrganizationMembers = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const { organizationId, pageSize = 50, pageToken } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  const limit = Math.min(Math.max(Number(pageSize) || 50, 1), 100);
  const db = getFirestore();

  // 1. Verify caller is an active member
  const callerMemberRef = db.collection("organizationMembers").doc(`${organizationId}_${uid}`);
  const callerSnap = await callerMemberRef.get();

  if (!callerSnap.exists || callerSnap.data()?.status !== "active") {
    throw new HttpsError("permission-denied", "You must be an active member to view the directory.");
  }

  // 2. Fetch Paginated Members
  let membersQuery = db.collection("organizationMembers")
    .where("organizationId", "==", organizationId)
    .orderBy("joinedAt", "desc")
    .limit(limit);

  if (pageToken && typeof pageToken === "string") {
    // Basic pagination using doc ID as cursor for simplicity in this implementation
    const cursorDoc = await db.collection("organizationMembers").doc(pageToken).get();
    if (cursorDoc.exists) {
      membersQuery = membersQuery.startAfter(cursorDoc);
    }
  }

  const membersSnap = await membersQuery.get();

  // 3. Resolve Sanitize Users and Departments
  const directory = [];
  let nextToken = null;

  if (!membersSnap.empty) {
    nextToken = membersSnap.docs[membersSnap.docs.length - 1].id;

    for (const memberDoc of membersSnap.docs) {
      const memberData = memberDoc.data();
      const targetUserId = memberData.userId;
      const deptId = memberData.departmentId;

      let firstName = "Unknown";
      let lastName = "User";
      let email = "";
      let photoUrl = null;

      try {
        const userSnap = await db.collection("users").doc(targetUserId).get();
        if (userSnap.exists) {
          const uData = userSnap.data()!;
          firstName = uData.firstName || firstName;
          lastName = uData.lastName || lastName;
          email = uData.email || email;
          photoUrl = uData.photoUrl || null;
        }
      } catch (e) {
        // Ignore individual user fetch failures
      }

      let departmentName = null;
      if (deptId) {
        try {
          const deptSnap = await db.collection("departments").doc(deptId).get();
          if (deptSnap.exists && deptSnap.data()?.organizationId === organizationId) {
            departmentName = deptSnap.data()?.name;
          }
        } catch (e) {
          // Ignore individual dept fetch failures
        }
      }

      directory.push({
        userId: targetUserId,
        firstName: firstName,
        lastName: lastName,
        displayName: `${firstName} ${lastName}`.trim(),
        email: email,
        photoUrl: photoUrl,
        role: memberData.role || "member",
        status: memberData.status || "inactive",
        departmentId: deptId || null,
        departmentName: departmentName,
        joinedAt: memberData.joinedAt ? memberData.joinedAt.toDate().toISOString() : null,
      });
    }
  }

  return {
    status: "success",
    members: directory,
    nextPageToken: membersSnap.docs.length === limit ? nextToken : null,
  };
});

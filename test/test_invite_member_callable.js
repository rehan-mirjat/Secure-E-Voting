const admin = require("firebase-admin");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp: initClientApp } = require("firebase/app");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const crypto = require("crypto");

process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

const PROJECT_ID = "vote-d1ae4";

// Initialize Admin SDK
admin.initializeApp({ projectId: PROJECT_ID });
const adminDb = getFirestore();

// Initialize Client SDK
const firebaseConfig = { projectId: PROJECT_ID, apiKey: "dummy-key" };
const clientApp = initClientApp(firebaseConfig);
const functions = getFunctions(clientApp, "us-central1");
const auth = getClientAuth(clientApp);

connectFunctionsEmulator(functions, '127.0.0.1', 5001);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });

async function runInvitationTest() {
  console.log("=== DIAGNOSTIC TEST: INVITE MEMBER CALLABLE ===");

  const ownerEmail = `owner_${Date.now()}@securevote.com`;
  const adminEmail = `admin_${Date.now()}@securevote.com`;
  const memberEmail = `member_${Date.now()}@securevote.com`;
  const targetEmail = "devvenom@gmai.com";

  try {
    const completeRegFn = httpsCallable(functions, 'completeRegistration');
    const inviteMemberFn = httpsCallable(functions, 'inviteMember');
    const acceptInvitationFn = httpsCallable(functions, 'acceptInvitation');

    // 1. Create Owner Account
    console.log("1. Creating Owner Account...");
    const ownerCred = await createUserWithEmailAndPassword(auth, ownerEmail, "Password123!");
    const ownerUid = ownerCred.user.uid;
    await completeRegFn({ firstName: "Owner", lastName: "Admin" });
    await adminDb.collection("users").doc(ownerUid).update({ emailVerified: true });

    // 2. Setup Organization via Admin SDK
    const orgId = `org_${Date.now()}`;
    await adminDb.collection("organizations").doc(orgId).set({
      name: "Nexaura",
      type: "corporate",
      email: "info@nexaura.com",
      status: "active",
      ownerId: ownerUid,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Owner Membership Document: organizationMembers/{organizationId}_{uid}
    await adminDb.collection("organizationMembers").doc(`${orgId}_${ownerUid}`).set({
      organizationId: orgId,
      userId: ownerUid,
      role: "owner",
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
    });

    console.log(`✅ Organization created: ${orgId} with Owner: ${ownerUid}`);

    // TEST A: Owner invites devvenom@gmai.com as 'member'
    console.log("\n--- TEST A: Owner invites new member (devvenom@gmai.com) ---");
    let rawTokenA = null;
    let invIdA = null;
    try {
      const res = await inviteMemberFn({
        organizationId: orgId,
        email: targetEmail,
        role: "member",
      });
      console.log("✅ TEST A SUCCESS:", res.data);
      rawTokenA = res.data.rawToken;
      invIdA = res.data.invitationId;
    } catch (err) {
      console.error("❌ TEST A FAILED:", { code: err.code, message: err.message, details: err.details });
    }

    // Verify Documents Written for Test A
    if (invIdA) {
      const invSnap = await adminDb.collection("organizationInvitations").doc(invIdA).get();
      const lockSnap = await adminDb.collection("organizationInvitationKeys").doc(`${orgId}_${targetEmail}`).get();
      console.log(`Document Check -> organizationInvitations/${invIdA} exists? ${invSnap.exists}`);
      console.log(`Document Check -> organizationInvitationKeys/${orgId}_${targetEmail} exists? ${lockSnap.exists}`);
    }

    // TEST F: Owner tries to invite devvenom@gmai.com AGAIN (Duplicate active invitation)
    console.log("\n--- TEST F: Owner tries duplicate invitation for devvenom@gmai.com ---");
    try {
      await inviteMemberFn({
        organizationId: orgId,
        email: targetEmail,
        role: "member",
      });
      console.log("❌ TEST F FAILED: Duplicate invitation should have been rejected.");
    } catch (err) {
      console.log("✅ TEST F PASSED (Expected already-exists):", { code: err.code, message: err.message });
    }

    // TEST C: Create Admin User & Test Admin Hierarchy Rules
    console.log("\n--- Setting up Admin User ---");
    const adminCred = await createUserWithEmailAndPassword(auth, adminEmail, "Password123!");
    const adminUid = adminCred.user.uid;
    await completeRegFn({ firstName: "Admin", lastName: "User" });
    await adminDb.collection("users").doc(adminUid).update({ emailVerified: true });

    await adminDb.collection("organizationMembers").doc(`${orgId}_${adminUid}`).set({
      organizationId: orgId,
      userId: adminUid,
      role: "admin",
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
    });

    // TEST C: Admin tries to invite 'admin' (Should fail: permission-denied)
    console.log("\n--- TEST C: Admin tries to invite 'admin' role ---");
    try {
      await inviteMemberFn({
        organizationId: orgId,
        email: "otheradmin@securevote.com",
        role: "admin",
      });
      console.log("❌ TEST C FAILED: Admin should not be able to invite Admin role.");
    } catch (err) {
      console.log("✅ TEST C PASSED (Expected permission-denied):", { code: err.code, message: err.message });
    }

    // TEST B: Admin invites member
    console.log("\n--- TEST B: Admin invites member ---");
    try {
      const res = await inviteMemberFn({
        organizationId: orgId,
        email: "member2@securevote.com",
        role: "member",
      });
      console.log("✅ TEST B SUCCESS:", res.data);
    } catch (err) {
      console.error("❌ TEST B FAILED:", { code: err.code, message: err.message });
    }

    // TEST D: Create Member User & Test Member Invitation Attempt
    console.log("\n--- Setting up Member User ---");
    const memberCred = await createUserWithEmailAndPassword(auth, memberEmail, "Password123!");
    const memberUid = memberCred.user.uid;
    await completeRegFn({ firstName: "Regular", lastName: "Member" });
    await adminDb.collection("users").doc(memberUid).update({ emailVerified: true });

    await adminDb.collection("organizationMembers").doc(`${orgId}_${memberUid}`).set({
      organizationId: orgId,
      userId: memberUid,
      role: "member",
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
    });

    // TEST D: Member tries to invite someone (Should fail: permission-denied)
    console.log("\n--- TEST D: Regular Member tries to issue invitation ---");
    try {
      await inviteMemberFn({
        organizationId: orgId,
        email: "someone@securevote.com",
        role: "member",
      });
      console.log("❌ TEST D FAILED: Member should not be able to invite.");
    } catch (err) {
      console.log("✅ TEST D PASSED (Expected permission-denied):", { code: err.code, message: err.message });
    }

    // TEST E: Try to invite someone who is ALREADY an active member
    console.log("\n--- TEST E: Try to invite existing active member (ownerEmail) ---");
    // Switch back to Owner
    await signInWithEmailAndPassword(auth, ownerEmail, "Password123!");
    try {
      await inviteMemberFn({
        organizationId: orgId,
        email: ownerEmail,
        role: "member",
      });
      console.log("❌ TEST E FAILED: Existing member invitation should have been rejected.");
    } catch (err) {
      console.log("✅ TEST E PASSED (Expected already-exists):", { code: err.code, message: err.message });
    }

    // TEST H: Accept generated invitation (rawTokenA) with matching invitee account
    console.log("\n--- TEST H: Accept generated invitation with rawTokenA ---");
    const inviteeCred = await createUserWithEmailAndPassword(auth, targetEmail, "Password123!");
    const inviteeUid = inviteeCred.user.uid;
    await completeRegFn({ firstName: "Invited", lastName: "Voter" });
    const { getAuth: getAdminAuth } = require("firebase-admin/auth");
    await getAdminAuth().updateUser(inviteeUid, { emailVerified: true });

    if (rawTokenA) {
      const acceptRes = await acceptInvitationFn({ rawToken: rawTokenA });
      console.log("✅ TEST H ACCEPT INVITATION SUCCESS:", acceptRes.data);

      // Verify membership record created: organizationMembers/{orgId}_{inviteeUid}
      const newMemberSnap = await adminDb.collection("organizationMembers").doc(`${orgId}_${inviteeUid}`).get();
      console.log(`Document Check -> organizationMembers/${orgId}_${inviteeUid} exists? ${newMemberSnap.exists}`);
      if (newMemberSnap.exists) {
        console.log("New Membership Role:", newMemberSnap.data().role, "Status:", newMemberSnap.data().status);
      }
    }

  } catch (error) {
    console.error("FATAL SCRIPT ERROR:", error);
  }
  process.exit(0);
}

runInvitationTest();

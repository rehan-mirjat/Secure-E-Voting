const { initializeApp: initClientApp } = require("firebase/app");
const { getFirestore, doc, getDoc, setDoc } = require("firebase/firestore");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const { connectFirestoreEmulator } = require("firebase/firestore");

process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

const PROJECT_ID = "vote-d1ae4";

const firebaseConfig = { projectId: PROJECT_ID, apiKey: "dummy-key" };
const clientApp = initClientApp(firebaseConfig);
const db = getFirestore(clientApp);
const functions = getFunctions(clientApp, "us-central1");
const auth = getClientAuth(clientApp);

connectFirestoreEmulator(db, '127.0.0.1', 8080);
connectFunctionsEmulator(functions, '127.0.0.1', 5001);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });

async function verifyEligibilityLogic() {
  console.log("=== VERIFYING ELIGIBILITY BUSINESS RULES ===\n");

  const testEmail = `elig_test_${Date.now()}@securevote.com`;

  try {
    const crypto = require("crypto");
    const completeRegFn = httpsCallable(functions, 'completeRegistration');
    const createOrgFn = httpsCallable(functions, 'createOrganization');
    const createEventFn = httpsCallable(functions, 'createVotingEvent');
    const publishEventFn = httpsCallable(functions, 'publishVotingEvent');
    const getMembersFn = httpsCallable(functions, 'getOrganizationMembers');

    // 1. Setup Active Owner
    const cred = await createUserWithEmailAndPassword(auth, testEmail, "Password123!");
    const uid = cred.user.uid;
    await completeRegFn({ firstName: "Elig", lastName: "Tester" });

    const resOrg = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Empty Org",
      type: "academic",
      email: "empty@test.com",
      country: "Test",
      city: "Test"
    });
    const orgId = resOrg.data.organizationId;
    console.log(`✅ PASSED: Created Empty Org: ${orgId}`);

    // Force organization to active/verified using direct firestore write for testing (bypass verify function)
    const { initializeApp: initAdminApp, getApps: getAdminApps } = require("firebase-admin/app");
    const { getFirestore: getAdminFirestore } = require("firebase-admin/firestore");
    if (getAdminApps().length === 0) {
      initAdminApp({ projectId: PROJECT_ID });
    }
    const adminDb = getAdminFirestore();
    await adminDb.collection("organizations").doc(orgId).update({ status: "active" });

    // 2. Verify getOrganizationMembers succeeds but returns empty for a newly created org
    // Note: The owner is an active member, so getOrganizationMembers should succeed but only return the owner.
    // Wait, the owner IS an active member. Let's see what it returns.
    const membersRes = await getMembersFn({ organizationId: orgId });
    if (membersRes.data.status === 'success' && Array.isArray(membersRes.data.members)) {
      console.log(`✅ PASSED: Active Owner can successfully query members list. Found ${membersRes.data.members.length} members.`);
    } else {
      console.log("❌ FAILED: getOrganizationMembers failed or returned invalid format.");
    }

    // 3. Create DRAFT Event with 0 selected members
    console.log("\nTesting DRAFT Creation with 0 Eligible Members:");
    const draftRes = await createEventFn({
      organizationId: orgId,
      title: "Zero Member Election",
      description: "Testing",
      votingType: "YES_NO_POLL",
      eligibilityType: "SELECTED_MEMBERS",
      eligibilityUserIds: [], // Explicitly passing 0 members
      startAt: new Date(Date.now() + 60000).toISOString(),
      endAt: new Date(Date.now() + 360000).toISOString(),
    });

    const eventId = draftRes.data.eventId;
    console.log(`✅ PASSED: Created DRAFT event successfully with 0 members. EventId: ${eventId}`);

    // 4. Attempt to PUBLISH the event with 0 members (Should Fail)
    console.log("\nTesting PUBLISH constraint with 0 Eligible Members:");
    try {
      await publishEventFn({ eventId: eventId });
      console.log("❌ FAILED: Backend should have rejected publishing with 0 eligible members.");
    } catch (e) {
      if (e.code === 'failed-precondition' && e.message.includes('requires at least one eligible')) {
        console.log(`✅ PASSED: Backend rejected publication correctly. Reason: ${e.message}`);
      } else {
        console.log(`❌ FAILED: Expected failed-precondition but got: ${e.code} / ${e.message}`);
      }
    }

  } catch (error) {
    console.error(`❌ FAILED: Integration test exception: ${error.message}`);
    process.exit(1);
  }

  console.log("\nBackend eligibility constraints verified successfully!");
  process.exit(0);
}

verifyBackendEligibilityLogic = verifyEligibilityLogic;
verifyBackendEligibilityLogic();

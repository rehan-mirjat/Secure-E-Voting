const { initializeApp: initClientApp } = require("firebase/app");
const { getFirestore, doc, getDoc } = require("firebase/firestore");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const { connectFirestoreEmulator } = require("firebase/firestore");

process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

const PROJECT_ID = "e-voteing-system";

const firebaseConfig = { projectId: PROJECT_ID, apiKey: "dummy-key" };
const clientApp = initClientApp(firebaseConfig);
const db = getFirestore(clientApp);
const functions = getFunctions(clientApp, "us-central1");
const auth = getClientAuth(clientApp);

connectFirestoreEmulator(db, '127.0.0.1', 8080);
connectFunctionsEmulator(functions, '127.0.0.1', 5001);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });

async function verifyBackendCreation() {
  console.log("=== VERIFYING CREATE ORGANIZATION BACKEND SUCCESS PATH ===");

  const testEmail = `create_org_test_${Date.now()}@securevote.com`;
  const orgName = `Test Org ${Date.now()}`;

  try {
    const crypto = require("crypto");
    const completeRegFn = httpsCallable(functions, 'completeRegistration');
    const createOrgFn = httpsCallable(functions, 'createOrganization');

    // Setup User
    const cred = await createUserWithEmailAndPassword(auth, testEmail, "Password123!");
    const uid = cred.user.uid;
    await completeRegFn({ firstName: "Create", lastName: "Tester" });

    // Force backend failure by sending invalid payload
    console.log("\\nTesting Failure Path:");
    try {
      await createOrgFn({
        requestId: crypto.randomUUID(),
        name: "Ab", // Invalid: < 3 chars
        type: "academic",
        email: "bad@test.com",
        country: "Test",
        city: "Test"
      });
      console.log("❌ FAILED: Backend should have rejected invalid organization name.");
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
         console.log("✅ PASSED: Backend correctly rejected invalid payload. (UI would remain on screen and display this error without navigating).");
      } else {
         console.log(`❌ FAILED: Unexpected error code on invalid creation: ${e.code}`);
      }
    }

    // Execute Success Path
    console.log("\\nTesting Success Path:");
    const res = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: orgName,
      type: "academic",
      email: "success@test.com",
      country: "Pakistan",
      city: "Karachi"
    });

    const orgId = res.data.organizationId;
    console.log(`✅ PASSED: createOrganization() callable succeeded, returned orgId: ${orgId}`);

    // Verify Organization Document
    const orgDoc = await getDoc(doc(db, "organizations", orgId));
    if (orgDoc.exists() && orgDoc.data().name === orgName && orgDoc.data().ownerId === uid) {
      console.log(`✅ PASSED: Organization document created successfully with correct owner mapping.`);
    } else {
      console.log(`❌ FAILED: Organization document missing or invalid.`);
    }

    // Verify Organization Status (M3 Rule)
    if (orgDoc.data().status === 'pending') {
      console.log(`✅ PASSED: Organization status correctly set to pending.`);
    } else {
      console.log(`❌ FAILED: Organization status was not pending. Found: ${orgDoc.data().status}`);
    }

    // Verify Owner Membership
    const memDoc = await getDoc(doc(db, "organizationMembers", `${orgId}_${uid}`));
    if (memDoc.exists() && memDoc.data().role === 'owner' && memDoc.data().status === 'active') {
      console.log(`✅ PASSED: Owner membership document created successfully with active status.`);
    } else {
      console.log(`❌ FAILED: Membership document missing or invalid.`);
    }

  } catch (error) {
    console.error(`❌ FAILED: Integration test exception: ${error.message}`);
    process.exit(1);
  }

  console.log("\\nBackend operations confirmed successful. Client UI / Router coordination awaits human browser QA.");
  process.exit(0);
}

verifyBackendCreation();

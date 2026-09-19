const { initializeApp: initClientApp } = require("firebase/app");
const { getFirestore, collection, query, where, orderBy, getDocs, setDoc, doc } = require("firebase/firestore");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signOut, signInWithEmailAndPassword } = require("firebase/auth");
const { connectFirestoreEmulator } = require("firebase/firestore");

// Set environment for Admin SDK to communicate with local emulator
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

const { initializeApp: initAdminApp, getApps: getAdminApps } = require("firebase-admin/app");
const { getAuth: getAdminAuth } = require("firebase-admin/auth");
const { getFirestore: getAdminFirestore, Timestamp } = require("firebase-admin/firestore");

const PROJECT_ID = "e-voteing-system";

if (getAdminApps().length === 0) {
  initAdminApp({ projectId: PROJECT_ID });
}
const adminAuth = getAdminAuth();
const adminDb = getAdminFirestore();

const firebaseConfig = { projectId: PROJECT_ID, apiKey: "dummy-key" };
const clientApp = initClientApp(firebaseConfig);
const db = getFirestore(clientApp);
const functions = getFunctions(clientApp, "us-central1");
const auth = getClientAuth(clientApp);

connectFirestoreEmulator(db, '127.0.0.1', 8080);
connectFunctionsEmulator(functions, '127.0.0.1', 5001);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });

async function runStep7DashboardTests() {
  console.log("=== RUNNING MILESTONE 4: STEP 7 DASHBOARD BACKEND INTEGRATION SUITE ===\n");
  let passed = true;

  function recordTest(id, description, isPassed, details = "") {
    if (!isPassed) passed = false;
    const symbol = isPassed ? "✅ PASSED" : "❌ FAILED";
    console.log(`${symbol} [${id}] ${description}${details ? ' - ' + details : ''}`);
  }

  const emailAdminA = `admin_a_dash_${Date.now()}@securevote.com`;
  const emailOwnerB = `owner_b_dash_${Date.now()}@securevote.com`;

  let adminAUid = null;
  let ownerBUid = null;
  let orgIdA = null;
  let orgIdB = null;

  try {
    const crypto = require("crypto");
    const createOrgFn = httpsCallable(functions, 'createOrganization');
    const completeRegFn = httpsCallable(functions, 'completeRegistration');

    // Setup Admin A in Org A
    const credAdminA = await createUserWithEmailAndPassword(auth, emailAdminA, "Password123!");
    adminAUid = credAdminA.user.uid;
    await completeRegFn({ firstName: "Admin", lastName: "A" });
    await adminAuth.updateUser(adminAUid, { emailVerified: true });

    // Refresh client auth token after verification
    await auth.currentUser.reload();
    await auth.currentUser.getIdToken(true);

    const resOrgA = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Dashboard Org A",
      type: "academic",
      email: "orga@test.com",
      country: "Pakistan",
      city: "Karachi"
    });
    orgIdA = resOrgA.data.organizationId;
    await adminDb.collection("organizations").doc(orgIdA).update({ status: "verified" });

    // Setup Owner B in Org B
    await signOut(auth);
    const credOwnerB = await createUserWithEmailAndPassword(auth, emailOwnerB, "Password123!");
    ownerBUid = credOwnerB.user.uid;
    await completeRegFn({ firstName: "Owner", lastName: "B" });
    await adminAuth.updateUser(ownerBUid, { emailVerified: true });

    // Refresh client auth token after verification
    await auth.currentUser.reload();
    await auth.currentUser.getIdToken(true);

    const resOrgB = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Dashboard Org B",
      type: "corporate",
      email: "orgb@test.com",
      country: "Pakistan",
      city: "Lahore"
    });
    orgIdB = resOrgB.data.organizationId;
    await adminDb.collection("organizations").doc(orgIdB).update({ status: "verified" });

    // Seed Events in Org A with Admin SDK to bypass strict lifecycle rules quickly
    // Note: These are minimal dashboard fixtures.
    // Lifecycle/schema validation is tested separately in Milestone 4 Steps 1–5.
    console.log("Seeding events with different statuses in Org A...");
    const statuses = ["DRAFT", "SCHEDULED", "ACTIVE", "CLOSED", "CANCELLED", "ARCHIVED"];
    const now = Date.now();

    for (let i = 0; i < statuses.length; i++) {
      const status = statuses[i];
      const startAtMillis = now + ((10 - i) * 60000); // 10 mins down to 5 mins ahead

      const eventRef = adminDb.collection("votingEvents").doc();
      await eventRef.set({
        id: eventRef.id,
        organizationId: orgIdA,
        title: `Event ${status}`,
        description: "Dashboard seed data",
        votingType: "CANDIDATE_ELECTION",
        privacyMode: "ANONYMOUS",
        eligibilityType: "ALL_MEMBERS",
        status: status,
        startAt: Timestamp.fromMillis(startAtMillis),
        endAt: Timestamp.fromMillis(startAtMillis + 300000),
        createdBy: adminAUid,
        createdAt: Timestamp.fromMillis(now),
        updatedAt: Timestamp.fromMillis(now),
      });
    }

    // Connect as Admin A
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdminA, "Password123!");

    // Execute 14.3, 14.4, 14.21
    console.log("Executing dashboard query as Admin A...");
    const qA = query(
      collection(db, "votingEvents"),
      where("organizationId", "==", orgIdA),
      orderBy("startAt", "desc")
    );

    let snapA;
    try {
      snapA = await getDocs(qA);
      recordTest("14.21", "Required organizationId + startAt DESC dashboard query executes successfully", true);
    } catch (e) {
      recordTest("14.21", "Required organizationId + startAt DESC dashboard query executes successfully", false, `Error: ${e.message}`);
    }

    if (snapA) {
      const returnedStatuses = snapA.docs.map(d => d.data().status).sort();
      const expectedStatuses = [...statuses].sort();

      recordTest("14.3", "Event list query retrieves all six required statuses", JSON.stringify(returnedStatuses) === JSON.stringify(expectedStatuses), `Returned: ${returnedStatuses.join(", ")}`);

      let isSorted = true;
      let prevStart = null;
      snapA.docs.forEach((d) => {
        const currentStart = d.data().startAt.toMillis();
        if (prevStart !== null && currentStart > prevStart) {
          isSorted = false;
        }
        prevStart = currentStart;
      });

      recordTest("14.4", "Event list is sorted natively by startAt DESC without client-side re-sorting", isSorted);
    }

    // Connect as Owner B (Cross-Tenant)
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailOwnerB, "Password123!");

    // Execute 14.20
    console.log("Executing cross-tenant dashboard query as Owner B...");
    const qB = query(
      collection(db, "votingEvents"),
      where("organizationId", "==", orgIdA), // Attempting to read Org A
      orderBy("startAt", "desc")
    );

    try {
      await getDocs(qB);
      recordTest("14.20", "Firestore Rules prevent cross-tenant votingEvent reads", false, "Query succeeded unexpectedly");
    } catch (e) {
      if (e.code === 'permission-denied') {
        recordTest("14.20", "Firestore Rules prevent cross-tenant votingEvent reads (permission-denied)", true);
      } else {
        recordTest("14.20", "Firestore Rules prevent cross-tenant votingEvent reads", false, `Error: ${e.code}`);
      }
    }

  } catch (e) {
    console.error(`❌ FAILED: Test runner exception: ${e.message}`);
    passed = false;
  }

  // Deep Cleanup via Admin SDK
  console.log("\nCleaning up test data deeply...");

  if (orgIdA) {
    const eventsA = await adminDb.collection("votingEvents").where("organizationId", "==", orgIdA).get();
    for (const d of eventsA.docs) await d.ref.delete();

    const membersA = await adminDb.collection("organizationMembers").where("organizationId", "==", orgIdA).get();
    for (const d of membersA.docs) await d.ref.delete();

    await adminDb.collection("organizations").doc(orgIdA).delete();
  }

  if (orgIdB) {
    const eventsB = await adminDb.collection("votingEvents").where("organizationId", "==", orgIdB).get();
    for (const d of eventsB.docs) await d.ref.delete();

    const membersB = await adminDb.collection("organizationMembers").where("organizationId", "==", orgIdB).get();
    for (const d of membersB.docs) await d.ref.delete();

    await adminDb.collection("organizations").doc(orgIdB).delete();
  }

  if (adminAUid) { try { await adminAuth.deleteUser(adminAUid); } catch(e) {} }
  if (ownerBUid) { try { await adminAuth.deleteUser(ownerBUid); } catch(e) {} }

  if (passed) {
    console.log("\n🚀 MILESTONE 4 — STEP 7: BACKEND DASHBOARD SUITE — PASSED 🚀");
    process.exit(0);
  } else {
    console.error("\n❌ MILESTONE 4 — STEP 7: BACKEND DASHBOARD SUITE — FAILED");
    process.exit(1);
  }
}

runStep7DashboardTests();

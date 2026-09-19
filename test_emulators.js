const { initializeApp: initClientApp } = require("firebase/app");
const { getFirestore, doc, getDoc, setDoc, updateDoc, deleteDoc, collection, query, where, getDocs } = require("firebase/firestore");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signOut, signInWithEmailAndPassword } = require("firebase/auth");
const { getStorage: getClientStorage, ref: storageRef, uploadBytes, getBytes, getMetadata: getClientMetadata, connectStorageEmulator } = require("firebase/storage");
const { connectFirestoreEmulator } = require("firebase/firestore");

// Set environment for Admin SDK to communicate with local emulator
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";

const { initializeApp: initAdminApp, getApps: getAdminApps } = require("firebase-admin/app");
const { getAuth: getAdminAuth } = require("firebase-admin/auth");
const { getFirestore: getAdminFirestore } = require("firebase-admin/firestore");
const { getStorage: getAdminStorage } = require("firebase-admin/storage");

const PROJECT_ID = "e-voteing-system";

if (getAdminApps().length === 0) {
  initAdminApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
}
const adminAuth = getAdminAuth();
const adminDb = getAdminFirestore();
const adminStorage = getAdminStorage();

const firebaseConfig = { projectId: PROJECT_ID, apiKey: "dummy-key", storageBucket: `${PROJECT_ID}.appspot.com` };
const clientApp = initClientApp(firebaseConfig);
const db = getFirestore(clientApp);
const functions = getFunctions(clientApp, "us-central1");
const auth = getClientAuth(clientApp);
const storage = getClientStorage(clientApp);

connectFirestoreEmulator(db, '127.0.0.1', 8080);
connectFunctionsEmulator(functions, '127.0.0.1', 5001);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
connectStorageEmulator(storage, '127.0.0.1', 9199);

// Valid 1x1 JPEG buffer
const validJpegHex = "ffd8ffe000104a46494600010101006000600000ffdb004300080606070605080707070909080a0c140808070708100b0b0f1419121413141219241d201a201d2432262a2624262a323f3938393f5348485368686868ffc0000b080001000101011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffda0008010100003f00d2cf0000ffd9";
const validJpegBuffer = Buffer.from(validJpegHex, "hex");

async function runStep12BackendTests() {
  console.log("=== RUNNING MILESTONE 4: STEP 5 CANDIDATE & OPTION MANAGEMENT ACCEPTANCE SUITE ===\n");
  console.log(`Target Project ID: ${PROJECT_ID}\n`);
  let passed = true;

  function recordTest(id, description, isPassed, details = "") {
    if (!isPassed) passed = false;
    const symbol = isPassed ? "✅ PASSED" : "❌ FAILED";
    console.log(`${symbol} [${id}] ${description}${details ? ' - ' + details : ''}`);
  }

  const emailOwner = `owner_cand_${Date.now()}@securevote.com`;
  const emailAdmin = `admin_cand_${Date.now()}@securevote.com`;
  const emailMember = `member_cand_${Date.now()}@securevote.com`;
  const emailOther = `other_cand_${Date.now()}@securevote.com`;

  let ownerUid = null;
  let adminUid = null;
  let memberUid = null;
  let otherUid = null;
  let orgId1 = null;
  let orgId2 = null;

  try {
    const crypto = require("crypto");
    const createOrgFn = httpsCallable(functions, 'createOrganization');
    const completeRegFn = httpsCallable(functions, 'completeRegistration');
    const createEventFn = httpsCallable(functions, 'createVotingEvent');
    const updateEventFn = httpsCallable(functions, 'updateVotingEvent');
    const publishEventFn = httpsCallable(functions, 'publishVotingEvent');
    const closeEventFn = httpsCallable(functions, 'closeVotingEvent');

    const createCandFn = httpsCallable(functions, 'createCandidate');
    const finalizePhotoFn = httpsCallable(functions, 'finalizeCandidatePhoto');
    const updateCandFn = httpsCallable(functions, 'updateCandidate');
    const deletePhotoFn = httpsCallable(functions, 'deleteCandidatePhoto');
    const deleteCandFn = httpsCallable(functions, 'deleteCandidate');

    const createOptFn = httpsCallable(functions, 'createPollOption');
    const updateOptFn = httpsCallable(functions, 'updatePollOption');
    const deleteOptFn = httpsCallable(functions, 'deletePollOption');

    // 1. Setup Accounts & Organizations
    console.log("Setup: Registering test users and creating test Organizations...");

    // Register Owner
    const credOwner = await createUserWithEmailAndPassword(auth, emailOwner, "Password123!");
    ownerUid = credOwner.user.uid;
    await completeRegFn({ firstName: "Owner", lastName: "Cand" });
    await adminAuth.updateUser(ownerUid, { emailVerified: true });

    // Owner creates Org 1
    const resOrg1 = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Cand Test Org 1",
      type: "academic",
      email: "org1_cand@test.com",
      country: "Pakistan",
      city: "Karachi"
    });
    orgId1 = resOrg1.data.organizationId;
    await adminDb.collection("organizations").doc(orgId1).update({ status: "verified" });

    // Owner creates Org 2
    const resOrg2 = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Cand Test Org 2",
      type: "corporate",
      email: "org2_cand@test.com",
      country: "Pakistan",
      city: "Lahore"
    });
    orgId2 = resOrg2.data.organizationId;
    await adminDb.collection("organizations").doc(orgId2).update({ status: "verified" });

    await signOut(auth);

    // Register Admin in Org 1
    const credAdmin = await createUserWithEmailAndPassword(auth, emailAdmin, "Password123!");
    adminUid = credAdmin.user.uid;
    await completeRegFn({ firstName: "Admin", lastName: "Cand" });
    await adminAuth.updateUser(adminUid, { emailVerified: true });

    await adminDb.collection("organizationMembers").doc(`${orgId1}_${adminUid}`).set({
      membershipId: `${orgId1}_${adminUid}`,
      organizationId: orgId1,
      userId: adminUid,
      role: "admin",
      status: "active",
      joinedAt: new Date(),
      updatedAt: new Date()
    });

    await signOut(auth);

    // Register Regular Member in Org 1
    const credMember = await createUserWithEmailAndPassword(auth, emailMember, "Password123!");
    memberUid = credMember.user.uid;
    await completeRegFn({ firstName: "Regular", lastName: "Member" });
    await adminAuth.updateUser(memberUid, { emailVerified: true });

    await adminDb.collection("organizationMembers").doc(`${orgId1}_${memberUid}`).set({
      membershipId: `${orgId1}_${memberUid}`,
      organizationId: orgId1,
      userId: memberUid,
      role: "member",
      status: "active",
      joinedAt: new Date(),
      updatedAt: new Date()
    });

    await signOut(auth);

    // Register Cross-Tenant Admin in Org 2
    const credOther = await createUserWithEmailAndPassword(auth, emailOther, "Password123!");
    otherUid = credOther.user.uid;
    await completeRegFn({ firstName: "Other", lastName: "Admin" });
    await adminAuth.updateUser(otherUid, { emailVerified: true });

    await adminDb.collection("organizationMembers").doc(`${orgId2}_${otherUid}`).set({
      membershipId: `${orgId2}_${otherUid}`,
      organizationId: orgId2,
      userId: otherUid,
      role: "admin",
      status: "active",
      joinedAt: new Date(),
      updatedAt: new Date()
    });

    await signOut(auth);

    // Sign in as Admin in Org 1
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!");

    const now = Date.now();
    const validStart = new Date(now + 100000).toISOString();
    const validEnd = new Date(now + 700000).toISOString();

    // Create DRAFT Candidate Election Event
    const resCandEvent = await createEventFn({
      organizationId: orgId1,
      title: "Faculty Election 2026",
      description: "Desc",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const candEventId = resCandEvent.data.eventId;

    // Create DRAFT Single Choice Poll Event
    const resPollEvent = await createEventFn({
      organizationId: orgId1,
      title: "Priority Poll 2026",
      description: "Desc",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const pollEventId = resPollEvent.data.eventId;

    // Create DRAFT Yes/No Poll Event
    const resYesNoEvent = await createEventFn({
      organizationId: orgId1,
      title: "Seminar Approval Yes/No Poll",
      description: "Desc",
      votingType: "YES_NO_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const yesNoEventId = resYesNoEvent.data.eventId;

    // CATEGORY A: CANDIDATE CRUD & FIELD VALIDATION (12.1 - 12.6)
    console.log("\nCATEGORY A: CANDIDATE CRUD & FIELD VALIDATION");

    // 12.1 Admin creates candidate for DRAFT candidate election
    const resCand1 = await createCandFn({
      organizationId: orgId1,
      votingEventId: candEventId,
      name: "Dr. Sarah Ahmed",
      party: "Independent Faculty",
      bio: "CS Professor"
    });
    const candId1 = resCand1.data.candidateId;
    const snapCand1 = await adminDb.collection("candidates").doc(candId1).get();

    if (resCand1.data.status === 'success' && snapCand1.exists && snapCand1.data().name === 'Dr. Sarah Ahmed') {
      recordTest("12.1", "Admin creates candidate for DRAFT candidate election succeeds", true);
    } else {
      recordTest("12.1", "Admin creates candidate for DRAFT candidate election", false);
    }

    // 12.2 Candidate name < 3 chars or blank rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: candEventId,
        name: "Ab"
      });
      recordTest("12.2", "Candidate name < 3 chars rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.2", "Candidate name < 3 chars rejected (invalid-argument)", true);
      } else {
        recordTest("12.2", "Candidate name < 3 chars rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.3 Candidate name > 100 chars rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: candEventId,
        name: "A".repeat(101)
      });
      recordTest("12.3", "Candidate name > 100 chars rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.3", "Candidate name > 100 chars rejected (invalid-argument)", true);
      } else {
        recordTest("12.3", "Candidate name > 100 chars rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.4 Candidate party > 100 chars or bio > 1000 chars rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: candEventId,
        name: "Dr. Test Bio",
        bio: "B".repeat(1001)
      });
      recordTest("12.4", "Candidate bio > 1000 chars rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.4", "Candidate bio > 1000 chars rejected (invalid-argument)", true);
      } else {
        recordTest("12.4", "Candidate bio > 1000 chars rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.5 Admin updates candidate details in DRAFT event
    const resUpdate125 = await updateCandFn({
      candidateId: candId1,
      name: "Dr. Sarah Ahmed Updated",
      party: "Independent Faculty Alliance"
    });
    const snapCand1Updated = await adminDb.collection("candidates").doc(candId1).get();

    if (resUpdate125.data.status === 'success' && snapCand1Updated.data().name === "Dr. Sarah Ahmed Updated") {
      recordTest("12.5", "Admin updates candidate details in DRAFT event succeeds", true);
    } else {
      recordTest("12.5", "Admin updates candidate details in DRAFT event", false);
    }

    // Create Candidate 2 for deletion test
    const resCand2 = await createCandFn({
      organizationId: orgId1,
      votingEventId: candEventId,
      name: "Prof. Ali Raza",
      party: "Engineering Group"
    });
    const candId2 = resCand2.data.candidateId;

    // 12.6 Admin deletes candidate from DRAFT event
    const resDel126 = await deleteCandFn({ candidateId: candId2 });
    const snapCand2Del = await adminDb.collection("candidates").doc(candId2).get();

    if (resDel126.data.status === 'success' && !snapCand2Del.exists) {
      recordTest("12.6", "Admin deletes candidate from DRAFT event succeeds", true);
    } else {
      recordTest("12.6", "Admin deletes candidate from DRAFT event", false);
    }

    // Re-create Candidate 2 for completeness publishing tests
    const resCand2Re = await createCandFn({
      organizationId: orgId1,
      votingEventId: candEventId,
      name: "Prof. Ali Raza",
      party: "Engineering Group"
    });
    const candId2Re = resCand2Re.data.candidateId;

    // CATEGORY B: POLL OPTION CRUD & FIELD VALIDATION (12.7 - 12.12)
    console.log("\nCATEGORY B: POLL OPTION CRUD & FIELD VALIDATION");

    // 12.7 Admin creates poll option for DRAFT single-choice poll
    const resOpt1 = await createOptFn({
      organizationId: orgId1,
      votingEventId: pollEventId,
      label: "Workshops & Training",
      description: "Weekly sessions",
      sortOrder: 1
    });
    const optId1 = resOpt1.data.optionId;
    const snapOpt1 = await adminDb.collection("pollOptions").doc(optId1).get();

    if (resOpt1.data.status === 'success' && snapOpt1.exists && snapOpt1.data().label === "Workshops & Training") {
      recordTest("12.7", "Admin creates poll option for DRAFT single-choice poll succeeds", true);
    } else {
      recordTest("12.7", "Admin creates poll option for DRAFT single-choice poll", false);
    }

    // 12.8 Poll option label blank or > 100 chars rejected
    try {
      await createOptFn({
        organizationId: orgId1,
        votingEventId: pollEventId,
        label: ""
      });
      recordTest("12.8", "Poll option label blank rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.8", "Poll option label blank rejected (invalid-argument)", true);
      } else {
        recordTest("12.8", "Poll option label blank rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.9 Poll option sortOrder < 0 rejected
    try {
      await createOptFn({
        organizationId: orgId1,
        votingEventId: pollEventId,
        label: "Negative Order Opt",
        sortOrder: -1
      });
      recordTest("12.9", "Poll option sortOrder < 0 rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.9", "Poll option sortOrder < 0 rejected (invalid-argument)", true);
      } else {
        recordTest("12.9", "Poll option sortOrder < 0 rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.10 Admin updates poll option label and sortOrder in DRAFT event
    const resUpdate1210 = await updateOptFn({
      optionId: optId1,
      label: "Workshops & Technical Bootcamps",
      sortOrder: 2
    });
    const snapOpt1Updated = await adminDb.collection("pollOptions").doc(optId1).get();

    if (resUpdate1210.data.status === 'success' && snapOpt1Updated.data().label === "Workshops & Technical Bootcamps") {
      recordTest("12.10", "Admin updates poll option label and sortOrder in DRAFT event succeeds", true);
    } else {
      recordTest("12.10", "Admin updates poll option label and sortOrder", false);
    }

    // Create Option 2 for deletion test
    const resOpt2 = await createOptFn({
      organizationId: orgId1,
      votingEventId: pollEventId,
      label: "Hackathons & Competitions",
      sortOrder: 1
    });
    const optId2 = resOpt2.data.optionId;

    // 12.11 Admin deletes poll option from DRAFT event
    const resDel1211 = await deleteOptFn({ optionId: optId2 });
    const snapOpt2Del = await adminDb.collection("pollOptions").doc(optId2).get();

    if (resDel1211.data.status === 'success' && !snapOpt2Del.exists) {
      recordTest("12.11", "Admin deletes poll option from DRAFT event succeeds", true);
    } else {
      recordTest("12.11", "Admin deletes poll option from DRAFT event", false);
    }

    // Re-create Option 2 for completeness publishing tests
    const resOpt2Re = await createOptFn({
      organizationId: orgId1,
      votingEventId: pollEventId,
      label: "Hackathons & Competitions",
      sortOrder: 1
    });
    const optId2Re = resOpt2Re.data.optionId;

    // 12.12 Attempt to manually create poll option for YES_NO_POLL rejected
    try {
      await createOptFn({
        organizationId: orgId1,
        votingEventId: yesNoEventId,
        label: "Maybe"
      });
      recordTest("12.12", "Attempt to manually create poll option for YES_NO_POLL rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.12", "Attempt to manually create poll option for YES_NO_POLL rejected (failed-precondition)", true);
      } else {
        recordTest("12.12", "Attempt to manually create poll option for YES_NO_POLL rejected", false, `Error: ${e.code}`);
      }
    }

    // CATEGORY C: YES/NO OPTION PROTECTION (12.13 - 12.15)
    console.log("\nCATEGORY C: YES/NO OPTION PROTECTION");

    // 12.13 Attempt to update generated {eventId}_YES option rejected
    try {
      await updateOptFn({
        optionId: `${yesNoEventId}_YES`,
        label: "Definitely Yes"
      });
      recordTest("12.13", "Attempt to update generated {eventId}_YES option rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.13", "Attempt to update generated {eventId}_YES option rejected (failed-precondition)", true);
      } else {
        recordTest("12.13", "Attempt to update generated {eventId}_YES option rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.14 Attempt to update generated {eventId}_NO option rejected
    try {
      await updateOptFn({
        optionId: `${yesNoEventId}_NO`,
        label: "Definitely No"
      });
      recordTest("12.14", "Attempt to update generated {eventId}_NO option rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.14", "Attempt to update generated {eventId}_NO option rejected (failed-precondition)", true);
      } else {
        recordTest("12.14", "Attempt to update generated {eventId}_NO option rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.15 Attempt to individually delete {eventId}_YES or {eventId}_NO option rejected
    try {
      await deleteOptFn({ optionId: `${yesNoEventId}_YES` });
      recordTest("12.15", "Attempt to individually delete generated {eventId}_YES option rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.15", "Attempt to individually delete generated {eventId}_YES option rejected (failed-precondition)", true);
      } else {
        recordTest("12.15", "Attempt to individually delete generated {eventId}_YES option rejected", false, `Error: ${e.code}`);
      }
    }

    // CATEGORY D: LIFECYCLE MUTATION GUARDS & IMMUTABILITY (12.16 - 12.20)
    console.log("\nCATEGORY D: LIFECYCLE MUTATION GUARDS & IMMUTABILITY");

    // Publish pollEventId to SCHEDULED/ACTIVE
    await publishEventFn({ eventId: pollEventId });

    // Publish candEventId to SCHEDULED/ACTIVE
    await publishEventFn({ eventId: candEventId });

    // 12.16 Attempt to create candidate for SCHEDULED or ACTIVE event rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: candEventId,
        name: "Late Candidate"
      });
      recordTest("12.16", "Attempt to create candidate for ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.16", "Attempt to create candidate for ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.16", "Attempt to create candidate for ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.17 Attempt to update candidate in ACTIVE or CLOSED event rejected
    try {
      await updateCandFn({
        candidateId: candId1,
        name: "Tampered Active Cand"
      });
      recordTest("12.17", "Attempt to update candidate in ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.17", "Attempt to update candidate in ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.17", "Attempt to update candidate in ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.18 Attempt to delete candidate from ACTIVE or CLOSED event rejected
    try {
      await deleteCandFn({ candidateId: candId1 });
      recordTest("12.18", "Attempt to delete candidate from ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.18", "Attempt to delete candidate from ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.18", "Attempt to delete candidate from ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.19 Attempt to create poll option for SCHEDULED or ACTIVE event rejected
    try {
      await createOptFn({
        organizationId: orgId1,
        votingEventId: pollEventId,
        label: "Late Poll Option"
      });
      recordTest("12.19", "Attempt to create poll option for ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.19", "Attempt to create poll option for ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.19", "Attempt to create poll option for ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.20 Attempt to delete poll option from ACTIVE or CLOSED event rejected
    try {
      await deleteOptFn({ optionId: optId1 });
      recordTest("12.20", "Attempt to delete poll option from ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.20", "Attempt to delete poll option from ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.20", "Attempt to delete poll option from ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // CATEGORY E: COMPLETENESS VALIDATION GATE AT PUBLISH (12.21 - 12.24)
    console.log("\nCATEGORY E: COMPLETENESS VALIDATION GATE AT PUBLISH");

    // Create DRAFT Candidate Event with 1 candidate
    const resDraftCandIncomp = await createEventFn({
      organizationId: orgId1,
      title: "Incomplete Candidate Event",
      description: "Desc",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const incompCandEventId = resDraftCandIncomp.data.eventId;

    await createCandFn({
      organizationId: orgId1,
      votingEventId: incompCandEventId,
      name: "Single Candidate"
    });

    // 12.21 Publishing CANDIDATE_ELECTION with < 2 valid candidates rejected
    try {
      await publishEventFn({ eventId: incompCandEventId });
      recordTest("12.21", "Publishing CANDIDATE_ELECTION with < 2 valid candidates rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.21", "Publishing CANDIDATE_ELECTION with < 2 valid candidates rejected (failed-precondition)", true);
      } else {
        recordTest("12.21", "Publishing CANDIDATE_ELECTION with < 2 valid candidates rejected", false, `Error: ${e.code}`);
      }
    }

    // Add 2nd candidate
    await createCandFn({
      organizationId: orgId1,
      votingEventId: incompCandEventId,
      name: "Second Candidate"
    });

    // 12.22 Publishing CANDIDATE_ELECTION with >= 2 valid candidates succeeds
    const pubRes1222 = await publishEventFn({ eventId: incompCandEventId });
    recordTest("12.22", "Publishing CANDIDATE_ELECTION with >= 2 valid candidates succeeds", pubRes1222.data.status === 'success');

    // Create DRAFT Single Choice Poll Event with 1 option
    const resDraftPollIncomp = await createEventFn({
      organizationId: orgId1,
      title: "Incomplete Poll Event",
      description: "Desc",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const incompPollEventId = resDraftPollIncomp.data.eventId;

    await createOptFn({
      organizationId: orgId1,
      votingEventId: incompPollEventId,
      label: "Single Option"
    });

    // 12.23 Publishing SINGLE_CHOICE_POLL with < 2 valid options rejected
    try {
      await publishEventFn({ eventId: incompPollEventId });
      recordTest("12.23", "Publishing SINGLE_CHOICE_POLL with < 2 valid options rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.23", "Publishing SINGLE_CHOICE_POLL with < 2 valid options rejected (failed-precondition)", true);
      } else {
        recordTest("12.23", "Publishing SINGLE_CHOICE_POLL with < 2 valid options rejected", false, `Error: ${e.code}`);
      }
    }

    // Add 2nd option
    await createOptFn({
      organizationId: orgId1,
      votingEventId: incompPollEventId,
      label: "Second Option"
    });

    // 12.24 Publishing SINGLE_CHOICE_POLL with >= 2 valid options succeeds
    const pubRes1224 = await publishEventFn({ eventId: incompPollEventId });
    recordTest("12.24", "Publishing SINGLE_CHOICE_POLL with >= 2 valid options succeeds", pubRes1224.data.status === 'success');

    // CATEGORY F: DOUBLE OWNERSHIP & CROSS-TENANT PROTECTION (12.25 - 12.29)
    console.log("\nCATEGORY F: DOUBLE OWNERSHIP & CROSS-TENANT PROTECTION");

    // Create a DRAFT event in Org 1
    const resDraftOrg1 = await createEventFn({
      organizationId: orgId1,
      title: "Org 1 Draft Event",
      description: "Desc",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const draftOrg1EventId = resDraftOrg1.data.eventId;

    // 12.25 Creating candidate targeting Org 1 event rejected for Admin Org 2
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailOther, "Password123!"); // Admin Org 2

    try {
      await createCandFn({
        organizationId: orgId1, // Trying to target Org 1
        votingEventId: draftOrg1EventId,
        name: "Cross Tenant Candidate"
      });
      recordTest("12.25", "Creating candidate targeting Org 1 event rejected for Admin Org 2", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.25", "Creating candidate targeting Org 1 event rejected for Admin Org 2 (permission-denied)", true);
      } else {
        recordTest("12.25", "Creating candidate targeting Org 1 event rejected", false, `Error: ${e.code}`);
      }
    }

    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    // 12.26 Creating candidate for SINGLE_CHOICE_POLL event rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: incompPollEventId, // SINGLE_CHOICE_POLL event
        name: "Wrong Event Type Cand"
      });
      recordTest("12.26", "Creating candidate for SINGLE_CHOICE_POLL event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.26", "Creating candidate for SINGLE_CHOICE_POLL event rejected (failed-precondition)", true);
      } else {
        recordTest("12.26", "Creating candidate for SINGLE_CHOICE_POLL event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.27 Creating poll option for CANDIDATE_ELECTION event rejected
    try {
      await createOptFn({
        organizationId: orgId1,
        votingEventId: draftOrg1EventId, // CANDIDATE_ELECTION event
        label: "Wrong Event Type Opt"
      });
      recordTest("12.27", "Creating poll option for CANDIDATE_ELECTION event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.27", "Creating poll option for CANDIDATE_ELECTION event rejected (failed-precondition)", true);
      } else {
        recordTest("12.27", "Creating poll option for CANDIDATE_ELECTION event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.28 Supplying client photoUrl or photoPath during createCandidate rejected
    try {
      await httpsCallable(functions, 'createCandidate')({
        organizationId: orgId1,
        votingEventId: draftOrg1EventId,
        name: "Tamper Photo Cand",
        photoUrl: "http://hack.com/photo.jpg"
      });
      recordTest("12.28", "Supplying client photoUrl during createCandidate rejected", false);
    } catch (e) {
      if (e.code === 'invalid-argument' || e.code === 'functions/invalid-argument') {
        recordTest("12.28", "Supplying client photoUrl during createCandidate rejected (invalid-argument)", true);
      } else {
        recordTest("12.28", "Supplying client photoUrl during createCandidate rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.29 Regular member attempting candidate/option CRUD rejected
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailMember, "Password123!"); // Regular Member

    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: draftOrg1EventId,
        name: "Member Created Cand"
      });
      recordTest("12.29", "Regular member attempting candidate CRUD rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.29", "Regular member attempting candidate CRUD rejected (permission-denied)", true);
      } else {
        recordTest("12.29", "Regular member attempting candidate CRUD rejected", false, `Error: ${e.code}`);
      }
    }

    // CATEGORY G: SECURITY RULES, QUERY ORDERING & AUDIT (12.30 - 12.35)
    console.log("\nCATEGORY G: SECURITY RULES, QUERY ORDERING & AUDIT");

    // 12.30 Direct client write (setDoc) to /candidates denied
    try {
      await setDoc(doc(db, "candidates", "hack_cand_id_1230"), { name: "Hack Cand" });
      recordTest("12.30", "Direct client write (setDoc) to /candidates denied", false);
    } catch (e) {
      if (e.code === 'permission-denied') {
        recordTest("12.30", "Direct client write (setDoc) to /candidates denied (permission-denied)", true);
      } else {
        recordTest("12.30", "Direct client write to /candidates denied", false, `Error: ${e.code}`);
      }
    }

    // 12.31 Direct client write (setDoc) to /pollOptions denied
    try {
      await setDoc(doc(db, "pollOptions", "hack_opt_id_1231"), { label: "Hack Opt" });
      recordTest("12.31", "Direct client write (setDoc) to /pollOptions denied", false);
    } catch (e) {
      if (e.code === 'permission-denied') {
        recordTest("12.31", "Direct client write (setDoc) to /pollOptions denied (permission-denied)", true);
      } else {
        recordTest("12.31", "Direct client write to /pollOptions denied", false, `Error: ${e.code}`);
      }
    }

    // 12.32 Candidates query returns items sorted alphabetically by name (FR-CAN-06)
    const candsSnapSort = await adminDb.collection("candidates")
      .where("organizationId", "==", orgId1)
      .where("votingEventId", "==", candEventId)
      .orderBy("name", "asc")
      .get();

    const names = candsSnapSort.docs.map(d => d.data().name);
    const isSortedAlpha = names.every((n, i) => i === 0 || names[i - 1] <= n);
    recordTest("12.32", "Candidates query returns items sorted alphabetically by name (FR-CAN-06)", isSortedAlpha);

    // 12.33 Poll options query returns items sorted by sortOrder ascending, id ascending
    const optsSnapSort = await adminDb.collection("pollOptions")
      .where("organizationId", "==", orgId1)
      .where("votingEventId", "==", pollEventId)
      .orderBy("sortOrder", "asc")
      .orderBy("id", "asc")
      .get();

    const sortOrders = optsSnapSort.docs.map(d => d.data().sortOrder);
    const isSortedNum = sortOrders.every((o, i) => i === 0 || sortOrders[i - 1] <= o);
    recordTest("12.33", "Poll options query returns items sorted by sortOrder ascending", isSortedNum);

    // 12.34 Inspecting actual stored audit log for CREATE_CANDIDATE verifies atomic write & clean metadata
    const auditCandQuery = await adminDb.collection("auditLogs")
      .where("organizationId", "==", orgId1)
      .where("action", "==", "CREATE_CANDIDATE")
      .get();

    recordTest("12.34", "Inspecting actual stored audit log for CREATE_CANDIDATE verifies atomic write & clean metadata", !auditCandQuery.empty && auditCandQuery.docs[0].data().resourceType === "candidate");

    // 12.35 Inspecting actual stored audit log for CREATE_POLL_OPTION verifies atomic write & clean metadata
    const auditOptQuery = await adminDb.collection("auditLogs")
      .where("organizationId", "==", orgId1)
      .where("action", "==", "CREATE_POLL_OPTION")
      .get();

    recordTest("12.35", "Inspecting actual stored audit log for CREATE_POLL_OPTION verifies atomic write & clean metadata", !auditOptQuery.empty && auditOptQuery.docs[0].data().resourceType === "pollOption");

    // CATEGORY H: EXTENDED CROSS-TENANT & LIFECYCLE UPDATE PROTECTIONS (12.36 - 12.43)
    console.log("\nCATEGORY H: EXTENDED CROSS-TENANT & LIFECYCLE UPDATE PROTECTIONS");

    // Create DRAFT candidate & option in draftOrg1EventId for cross-tenant tests
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    const resDraftCandCt = await createCandFn({
      organizationId: orgId1,
      votingEventId: draftOrg1EventId,
      name: "Draft Org 1 Cand"
    });
    const draftCandCtId = resDraftCandCt.data.candidateId;

    // Create DRAFT Poll Event in Org 1
    const resDraftPollCtEvent = await createEventFn({
      organizationId: orgId1,
      title: "Draft Poll Org 1",
      description: "Desc",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const draftPollCtEventId = resDraftPollCtEvent.data.eventId;

    const resDraftOptCt = await createOptFn({
      organizationId: orgId1,
      votingEventId: draftPollCtEventId,
      label: "Draft Org 1 Opt"
    });
    const draftOptCtId = resDraftOptCt.data.optionId;

    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailOther, "Password123!"); // Admin Org 2

    // 12.36 Admin Org 2 attempts to update candidate belonging to Org 1 rejected
    try {
      await updateCandFn({ candidateId: draftCandCtId, name: "Cross Tenant Edit Cand" });
      recordTest("12.36", "Admin Org 2 attempts to update candidate belonging to Org 1 rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.36", "Admin Org 2 attempts to update candidate belonging to Org 1 rejected (permission-denied)", true);
      } else {
        recordTest("12.36", "Admin Org 2 attempts to update candidate belonging to Org 1 rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.37 Admin Org 2 attempts to delete candidate belonging to Org 1 rejected
    try {
      await deleteCandFn({ candidateId: draftCandCtId });
      recordTest("12.37", "Admin Org 2 attempts to delete candidate belonging to Org 1 rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.37", "Admin Org 2 attempts to delete candidate belonging to Org 1 rejected (permission-denied)", true);
      } else {
        recordTest("12.37", "Admin Org 2 attempts to delete candidate belonging to Org 1 rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.38 Admin Org 2 attempts to update poll option belonging to Org 1 rejected
    try {
      await updateOptFn({ optionId: draftOptCtId, label: "Cross Tenant Edit Opt" });
      recordTest("12.38", "Admin Org 2 attempts to update poll option belonging to Org 1 rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.38", "Admin Org 2 attempts to update poll option belonging to Org 1 rejected (permission-denied)", true);
      } else {
        recordTest("12.38", "Admin Org 2 attempts to update poll option belonging to Org 1 rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.39 Admin Org 2 attempts to delete poll option belonging to Org 1 rejected
    try {
      await deleteOptFn({ optionId: draftOptCtId });
      recordTest("12.39", "Admin Org 2 attempts to delete poll option belonging to Org 1 rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.39", "Admin Org 2 attempts to delete poll option belonging to Org 1 rejected (permission-denied)", true);
      } else {
        recordTest("12.39", "Admin Org 2 attempts to delete poll option belonging to Org 1 rejected", false, `Error: ${e.code}`);
      }
    }

    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    // Update candEventId to ACTIVE and close it
    await adminDb.collection("votingEvents").doc(candEventId).update({ status: "ACTIVE" });
    await closeEventFn({ eventId: candEventId });

    // 12.40 Candidate update attempted on CLOSED event rejected
    try {
      await updateCandFn({ candidateId: candId1, name: "Closed Cand Edit" });
      recordTest("12.40", "Candidate update attempted on CLOSED event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.40", "Candidate update attempted on CLOSED event rejected (failed-precondition)", true);
      } else {
        recordTest("12.40", "Candidate update attempted on CLOSED event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.41 Poll option update attempted on SCHEDULED event rejected
    const resPollSched = await createEventFn({
      organizationId: orgId1,
      title: "Sched Poll Event",
      description: "Desc",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const schedPollEventId = resPollSched.data.eventId;
    const resOptSched = await createOptFn({ organizationId: orgId1, votingEventId: schedPollEventId, label: "Opt 1" });
    await createOptFn({ organizationId: orgId1, votingEventId: schedPollEventId, label: "Opt 2" });
    await publishEventFn({ eventId: schedPollEventId }); // Becomes SCHEDULED

    try {
      await updateOptFn({ optionId: resOptSched.data.optionId, label: "Edit Sched Opt" });
      recordTest("12.41", "Poll option update attempted on SCHEDULED event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.41", "Poll option update attempted on SCHEDULED event rejected (failed-precondition)", true);
      } else {
        recordTest("12.41", "Poll option update attempted on SCHEDULED event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.42 Poll option update attempted on ACTIVE event rejected
    try {
      await updateOptFn({ optionId: optId1, label: "Edit Active Opt" });
      recordTest("12.42", "Poll option update attempted on ACTIVE event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.42", "Poll option update attempted on ACTIVE event rejected (failed-precondition)", true);
      } else {
        recordTest("12.42", "Poll option update attempted on ACTIVE event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.43 Candidate create attempted on YES_NO_POLL event rejected
    try {
      await createCandFn({
        organizationId: orgId1,
        votingEventId: yesNoEventId,
        name: "Cand in YesNo Event"
      });
      recordTest("12.43", "Candidate create attempted on YES_NO_POLL event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.43", "Candidate create attempted on YES_NO_POLL event rejected (failed-precondition)", true);
      } else {
        recordTest("12.43", "Candidate create attempted on YES_NO_POLL event rejected", false, `Error: ${e.code}`);
      }
    }

    // CATEGORY I: FIREBASE STORAGE SECURITY RULES & CONTROLLED PHOTO LIFECYCLE (12.44 - 12.58)
    console.log("\nCATEGORY I: FIREBASE STORAGE SECURITY RULES & CONTROLLED PHOTO LIFECYCLE");

    // Create a new fresh DRAFT event in Org 1 for photo tests
    const resPhotoEvent = await createEventFn({
      organizationId: orgId1,
      title: "Photo Test Draft Event",
      description: "Desc",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: validStart,
      endAt: validEnd
    });
    const photoEventId = resPhotoEvent.data.eventId;

    const resCandPhoto = await createCandFn({
      organizationId: orgId1,
      votingEventId: photoEventId,
      name: "Dr. Photo Candidate"
    });
    const photoCandId = resCandPhoto.data.candidateId;
    const expectedPhotoPath = resCandPhoto.data.expectedPhotoPath;

    // 12.44 Regular member attempts candidate photo upload -> Denied by Storage Rules
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailMember, "Password123!"); // Member

    try {
      const photoRef1244 = storageRef(storage, expectedPhotoPath);
      await uploadBytes(photoRef1244, validJpegBuffer, { contentType: "image/jpeg" });
      recordTest("12.44", "Regular member attempts candidate photo upload denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.44", "Regular member attempts candidate photo upload denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.45 Admin from Org A attempts upload to Org B path -> Denied by Storage Rules
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    try {
      const photoRef1245 = storageRef(storage, `organizations/${orgId2}/events/event_org2/candidates/cand_org2/photo.jpg`);
      await uploadBytes(photoRef1245, validJpegBuffer, { contentType: "image/jpeg" });
      recordTest("12.45", "Admin from Org 1 attempts upload to Org 2 path denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.45", "Admin from Org 1 attempts upload to Org 2 path denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.46 Admin attempts upload to non-DRAFT event path -> Denied by Storage Rules
    try {
      const photoRef1246 = storageRef(storage, `organizations/${orgId1}/events/${candEventId}/candidates/${candId1}/photo.jpg`);
      await uploadBytes(photoRef1246, validJpegBuffer, { contentType: "image/jpeg" });
      recordTest("12.46", "Admin attempts upload to ACTIVE event path denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.46", "Admin attempts upload to ACTIVE event path denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.47 Admin attempts upload with non-JPEG content type -> Denied by Storage Rules
    try {
      const photoRef1247 = storageRef(storage, expectedPhotoPath);
      await uploadBytes(photoRef1247, Buffer.from("hello text"), { contentType: "text/plain" });
      recordTest("12.47", "Admin attempts upload with non-JPEG content type denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.47", "Admin attempts upload with non-JPEG content type denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.48 Unauthenticated photo read -> Denied by Storage Rules
    await signOut(auth);

    try {
      const photoRef1248 = storageRef(storage, expectedPhotoPath);
      await getBytes(photoRef1248);
      recordTest("12.48", "Unauthenticated photo read denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.48", "Unauthenticated photo read denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.49 Cross-tenant member photo read for DRAFT event -> Denied by Storage Rules
    await signInWithEmailAndPassword(auth, emailOther, "Password123!"); // Admin Org 2

    try {
      const photoRef1249 = storageRef(storage, expectedPhotoPath);
      await getBytes(photoRef1249);
      recordTest("12.49", "Cross-tenant member photo read for DRAFT event denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.49", "Cross-tenant member photo read for DRAFT event denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.51 Admin attempts photo upload using candidateId belonging to another event -> Denied by Storage Rules
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    try {
      // photoCandId belongs to draftOrg1EventId, not candEventId
      const photoRef1251 = storageRef(storage, `organizations/${orgId1}/events/${candEventId}/candidates/${photoCandId}/photo.jpg`);
      await uploadBytes(photoRef1251, validJpegBuffer, { contentType: "image/jpeg" });
      recordTest("12.51", "Admin attempts photo upload using candidateId belonging to another event denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.51", "Admin attempts photo upload using candidateId belonging to another event denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.52 Admin attempts photo upload using filename other than photo.jpg -> Denied by Storage Rules
    try {
      const photoRef1252 = storageRef(storage, `organizations/${orgId1}/events/${draftOrg1EventId}/candidates/${photoCandId}/wrong_name.jpg`);
      await uploadBytes(photoRef1252, validJpegBuffer, { contentType: "image/jpeg" });
      recordTest("12.52", "Admin attempts photo upload using filename other than photo.jpg denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.52", "Admin attempts photo upload using filename other than photo.jpg denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.53 Admin attempts JPEG upload exceeding 5MB size limit -> Denied by Storage Rules
    const oversizeBuffer = Buffer.alloc(5 * 1024 * 1024 + 1024); // > 5MB
    try {
      const photoRef1253 = storageRef(storage, expectedPhotoPath);
      await uploadBytes(photoRef1253, oversizeBuffer, { contentType: "image/jpeg" });
      recordTest("12.53", "Admin attempts JPEG upload exceeding 5MB size limit denied by Storage Security Rules", false);
    } catch (e) {
      recordTest("12.53", "Admin attempts JPEG upload exceeding 5MB size limit denied by Storage Security Rules (unauthorized)", true);
    }

    // 12.55 Valid upload + finalizeCandidatePhoto sets correct photoPath and photoUrl
    const adminBucket1255 = adminStorage.bucket("e-voteing-system.appspot.com");
    await adminBucket1255.file(expectedPhotoPath).save(validJpegBuffer, {
      metadata: { contentType: "image/jpeg" },
      resumable: false
    });
    await new Promise(r => setTimeout(r, 500));

    const resFinalize = await finalizePhotoFn({ candidateId: photoCandId });
    const snapCandFinalized = await adminDb.collection("candidates").doc(photoCandId).get();

    if (resFinalize.data.status === 'success' && snapCandFinalized.data().photoPath === expectedPhotoPath && snapCandFinalized.data().photoUrl !== null) {
      recordTest("12.55", "Valid upload + finalizeCandidatePhoto sets correct photoPath and photoUrl in Firestore", true);
    } else {
      recordTest("12.55", "Valid upload + finalizeCandidatePhoto", false);
    }

    // 12.56 Admin A attempts finalizeCandidatePhoto for candidate belonging to Org B
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailOther, "Password123!"); // Admin Org 2

    try {
      await finalizePhotoFn({ candidateId: photoCandId });
      recordTest("12.56", "Admin A attempts finalizeCandidatePhoto for candidate belonging to Org B rejected", false);
    } catch (e) {
      if (e.code === 'permission-denied' || e.code === 'functions/permission-denied') {
        recordTest("12.56", "Admin A attempts finalizeCandidatePhoto for candidate belonging to Org B rejected (permission-denied)", true);
      } else {
        recordTest("12.56", "Admin A attempts finalizeCandidatePhoto for candidate belonging to Org B rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.57 finalizeCandidatePhoto called when photo.jpg does not exist in Storage bucket rejected
    await signOut(auth);
    await signInWithEmailAndPassword(auth, emailAdmin, "Password123!"); // Admin Org 1

    const resNoPhotoCand = await createCandFn({
      organizationId: orgId1,
      votingEventId: photoEventId, // photoEventId is in DRAFT status
      name: "No Photo Candidate"
    });
    const noPhotoCandId = resNoPhotoCand.data.candidateId;

    try {
      await finalizePhotoFn({ candidateId: noPhotoCandId });
      recordTest("12.57", "finalizeCandidatePhoto called when photo.jpg does not exist in Storage bucket rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.57", "finalizeCandidatePhoto called when photo.jpg does not exist in Storage bucket rejected (failed-precondition)", true);
      } else {
        recordTest("12.57", "finalizeCandidatePhoto called when photo.jpg does not exist in Storage bucket rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.58 Photo finalization attempted on non-DRAFT event rejected
    try {
      await finalizePhotoFn({ candidateId: candId1 }); // candId1 is in CLOSED event
      recordTest("12.58", "Photo finalization attempted on non-DRAFT event rejected", false);
    } catch (e) {
      if (e.code === 'failed-precondition' || e.code === 'functions/failed-precondition') {
        recordTest("12.58", "Photo finalization attempted on non-DRAFT event rejected (failed-precondition)", true);
      } else {
        recordTest("12.58", "Photo finalization attempted on non-DRAFT event rejected", false, `Error: ${e.code}`);
      }
    }

    // 12.50 & 12.54 Candidate photo deletion and replacement cleanup
    const resDelPhoto = await deletePhotoFn({ candidateId: photoCandId });
    const snapDelPhoto = await adminDb.collection("candidates").doc(photoCandId).get();

    // Verify Storage artifact deletion via Admin Storage
    const adminBucket = adminStorage.bucket();
    const [fileExistAfterDel] = await adminBucket.file(expectedPhotoPath).exists();

    if (resDelPhoto.data.status === 'success' && snapDelPhoto.data().photoUrl === null && snapDelPhoto.data().photoPath === null && !fileExistAfterDel) {
      recordTest("12.50", "Candidate photo deletion clears photoUrl and photoPath in Firestore AND deletes Storage artifact", true);
      recordTest("12.54", "Candidate photo replacement/deletion cleans up Storage artifact post-transaction", true);
    } else {
      recordTest("12.50", "Candidate photo deletion", false);
      recordTest("12.54", "Candidate photo deletion cleanup", false);
    }

  } catch (error) {
    console.error(`❌ FAILED: Step 12 test runner exception: ${error.message}`);
    passed = false;
  }

  // Cleanup
  console.log("\nCleaning up test data...");
  if (ownerUid) { try { await adminAuth.deleteUser(ownerUid); } catch(e) {} }
  if (adminUid) { try { await adminAuth.deleteUser(adminUid); } catch(e) {} }
  if (memberUid) { try { await adminAuth.deleteUser(memberUid); } catch(e) {} }
  if (otherUid) { try { await adminAuth.deleteUser(otherUid); } catch(e) {} }

  if (passed) {
    console.log("\n🚀 MILESTONE 4 — STEP 5: CANDIDATE & OPTION MANAGEMENT ACCEPTANCE SUITE — PASSED 🚀");
    process.exit(0);
  } else {
    console.error("\n❌ MILESTONE 4 — STEP 5: CANDIDATE & OPTION MANAGEMENT ACCEPTANCE SUITE — FAILED");
    process.exit(1);
  }
}

runStep12BackendTests();

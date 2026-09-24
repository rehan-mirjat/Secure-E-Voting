const { initializeApp: initClientApp } = require("firebase/app");
const { getFirestore, doc, addDoc, setDoc, updateDoc, deleteDoc, collection } = require("firebase/firestore");
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require("firebase/functions");
const { getAuth: getClientAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require("firebase/auth");
const { connectFirestoreEmulator } = require("firebase/firestore");
const { initializeApp: initAdminApp, getApps: getAdminApps } = require("firebase-admin/app");
const { getFirestore: getAdminFirestore } = require("firebase-admin/firestore");

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

if (getAdminApps().length === 0) {
  initAdminApp({ projectId: PROJECT_ID });
}
const adminDb = getAdminFirestore();

let passCount = 0;
let failCount = 0;

function reportPass(msg) {
  console.log(`✅ PASSED: ${msg}`);
  passCount++;
}

function reportFail(msg) {
  console.log(`❌ FAILED: ${msg}`);
  failCount++;
}

async function runM5Step1HardeningTests() {
  console.log("=== MILESTONE 5 - STEP 1: COMPREHENSIVE BACKEND & CLIENT SECURITY SUITE ===\n");

  const timestamp = Date.now();
  const ownerEmail = `voter_owner_${timestamp}@securevote.com`;
  const voter1Email = `voter1_${timestamp}@securevote.com`;
  const voter2Email = `voter2_${timestamp}@securevote.com`;
  const nonMemberEmail = `nonmember_${timestamp}@securevote.com`;

  try {
    const crypto = require("crypto");
    const completeRegFn = httpsCallable(functions, 'completeRegistration');
    const createOrgFn = httpsCallable(functions, 'createOrganization');
    const createEventFn = httpsCallable(functions, 'createVotingEvent');
    const createCandFn = httpsCallable(functions, 'createCandidate');
    const createOptFn = httpsCallable(functions, 'createPollOption');
    const publishEventFn = httpsCallable(functions, 'publishVotingEvent');
    const castVoteFn = httpsCallable(functions, 'castVote');

    // 1. Setup Accounts
    const ownerCred = await createUserWithEmailAndPassword(auth, ownerEmail, "Password123!");
    const ownerUid = ownerCred.user.uid;
    await completeRegFn({ firstName: "Owner", lastName: "Admin" });

    // Org 1 (Primary Org)
    const orgRes1 = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Primary Org",
      type: "academic",
      email: "org1@test.com",
      country: "Test",
      city: "Test"
    });
    const orgId1 = orgRes1.data.organizationId;
    await adminDb.collection("organizations").doc(orgId1).update({ status: "active" });

    // Org 2 (Cross-tenant Org)
    const orgRes2 = await createOrgFn({
      requestId: crypto.randomUUID(),
      name: "Cross Tenant Org",
      type: "academic",
      email: "org2@test.com",
      country: "Test",
      city: "Test"
    });
    const orgId2 = orgRes2.data.organizationId;
    await adminDb.collection("organizations").doc(orgId2).update({ status: "active" });

    // Setup Voter 1 (Member in Org 1)
    const voter1Cred = await createUserWithEmailAndPassword(auth, voter1Email, "Password123!");
    const voter1Uid = voter1Cred.user.uid;
    await completeRegFn({ firstName: "Voter", lastName: "One" });
    await adminDb.collection("organizationMembers").doc(`${orgId1}_${voter1Uid}`).set({
      membershipId: `${orgId1}_${voter1Uid}`,
      organizationId: orgId1,
      userId: voter1Uid,
      role: "member",
      status: "active",
      joinedAt: new Date()
    });

    // Setup Voter 2 (Member in Org 1 with Department DeptA)
    const voter2Cred = await createUserWithEmailAndPassword(auth, voter2Email, "Password123!");
    const voter2Uid = voter2Cred.user.uid;
    await completeRegFn({ firstName: "Voter", lastName: "Two" });
    await adminDb.collection("organizationMembers").doc(`${orgId1}_${voter2Uid}`).set({
      membershipId: `${orgId1}_${voter2Uid}`,
      organizationId: orgId1,
      userId: voter2Uid,
      role: "member",
      status: "active",
      departmentId: "dept_a_id",
      joinedAt: new Date()
    });

    // Setup Department A in Org 1
    await adminDb.collection("departments").doc("dept_a_id").set({
      id: "dept_a_id",
      organizationId: orgId1,
      name: "Department A",
      createdAt: new Date()
    });

    // Setup Non-Member
    const nonMemberCred = await createUserWithEmailAndPassword(auth, nonMemberEmail, "Password123!");
    const nonMemberUid = nonMemberCred.user.uid;
    await completeRegFn({ firstName: "Non", lastName: "Member" });

    // Switch client auth to Owner
    await signInWithEmailAndPassword(auth, ownerEmail, "Password123!");

    // Create Candidate Event in Org 1
    const now = Date.now();
    const eventRes1 = await createEventFn({
      organizationId: orgId1,
      title: "Active Election Org 1",
      description: "Testing",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const eventId1 = eventRes1.data.eventId;
    const cand1Res = await createCandFn({ organizationId: orgId1, votingEventId: eventId1, name: "Cand A1", party: "P1" });
    const cand1BRes = await createCandFn({ organizationId: orgId1, votingEventId: eventId1, name: "Cand A2", party: "P1" });
    const cand1Id = cand1Res.data.candidateId;
    await publishEventFn({ eventId: eventId1 });

    // Create Candidate Event in Org 2 (Cross-tenant Event)
    const eventRes2 = await createEventFn({
      organizationId: orgId2,
      title: "Active Election Org 2",
      description: "Testing",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const eventId2 = eventRes2.data.eventId;
    const cand2Res = await createCandFn({ organizationId: orgId2, votingEventId: eventId2, name: "Cand Org2", party: "P2" });
    await createCandFn({ organizationId: orgId2, votingEventId: eventId2, name: "Cand Org2 B", party: "P2" });
    const cand2Id = cand2Res.data.candidateId;
    await publishEventFn({ eventId: eventId2 });

    // Create Future Event (Not Started)
    const futureRes = await createEventFn({
      organizationId: orgId1,
      title: "Future Election",
      description: "Testing",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now + 3600000).toISOString(),
      endAt: new Date(now + 7200000).toISOString(),
    });
    const futureEventId = futureRes.data.eventId;
    const futureCandRes = await createCandFn({ organizationId: orgId1, votingEventId: futureEventId, name: "Future Cand", party: "P1" });
    await createCandFn({ organizationId: orgId1, votingEventId: futureEventId, name: "Future Cand 2", party: "P1" });
    const futureCandId = futureCandRes.data.candidateId;
    await publishEventFn({ eventId: futureEventId });
    await adminDb.collection("votingEvents").doc(futureEventId).update({ status: "ACTIVE" });

    // Create Past Event (Ended)
    const pastRes = await createEventFn({
      organizationId: orgId1,
      title: "Past Election",
      description: "Testing",
      votingType: "CANDIDATE_ELECTION",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now + 60000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const pastEventId = pastRes.data.eventId;
    const pastCandRes = await createCandFn({ organizationId: orgId1, votingEventId: pastEventId, name: "Past Cand", party: "P1" });
    await createCandFn({ organizationId: orgId1, votingEventId: pastEventId, name: "Past Cand 2", party: "P1" });
    const pastCandId = pastCandRes.data.candidateId;
    await publishEventFn({ eventId: pastEventId });
    await adminDb.collection("votingEvents").doc(pastEventId).update({
      status: "ACTIVE",
      startAt: new Date(now - 7200000),
      endAt: new Date(now - 3600000)
    });

    // Create YES/NO Poll Event
    const yesNoRes = await createEventFn({
      organizationId: orgId1,
      title: "Yes No Poll",
      description: "Testing",
      votingType: "YES_NO_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const yesNoEventId = yesNoRes.data.eventId;
    await publishEventFn({ eventId: yesNoEventId });

    // Create Selected Dept Event (Eligible for Dept A)
    const deptRes = await createEventFn({
      organizationId: orgId1,
      title: "Dept A Election",
      description: "Testing",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "SELECTED_DEPARTMENTS",
      eligibilityDepartmentIds: ["dept_a_id"],
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const deptEventId = deptRes.data.eventId;
    const optRes = await createOptFn({ organizationId: orgId1, votingEventId: deptEventId, label: "Option 1" });
    await createOptFn({ organizationId: orgId1, votingEventId: deptEventId, label: "Option 2" });
    const opt1Id = optRes.data.optionId;
    await publishEventFn({ eventId: deptEventId });

    // Create Selected Members Event (Eligible ONLY for Voter 2)
    const selMembersRes = await createEventFn({
      organizationId: orgId1,
      title: "Selected Members Election",
      description: "Testing",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "SELECTED_MEMBERS",
      eligibilityUserIds: [voter2Uid],
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const selMembersEventId = selMembersRes.data.eventId;
    const selOptRes = await createOptFn({ organizationId: orgId1, votingEventId: selMembersEventId, label: "Member Option 1" });
    await createOptFn({ organizationId: orgId1, votingEventId: selMembersEventId, label: "Member Option 2" });
    const selOpt1Id = selOptRes.data.optionId;
    await publishEventFn({ eventId: selMembersEventId });

    // Create ALL_MEMBERS Single-Choice Poll (to test Wrong Choice Type directly)
    const allMembersPollRes = await createEventFn({
      organizationId: orgId1,
      title: "All Members Poll",
      description: "Testing Choice Validation",
      votingType: "SINGLE_CHOICE_POLL",
      eligibilityType: "ALL_MEMBERS",
      startAt: new Date(now - 10000).toISOString(),
      endAt: new Date(now + 3600000).toISOString(),
    });
    const allMembersPollEventId = allMembersPollRes.data.eventId;
    await createOptFn({ organizationId: orgId1, votingEventId: allMembersPollEventId, label: "Poll Opt 1" });
    await createOptFn({ organizationId: orgId1, votingEventId: allMembersPollEventId, label: "Poll Opt 2" });
    await publishEventFn({ eventId: allMembersPollEventId });

    console.log("✅ Fixtures Setup Complete.\n");

    // =========================================================================
    // 1. BACKEND HARKENING & REJECTION TESTS
    // =========================================================================

    // Test 1: Event not started
    // Test 1: Event not started
    await signInWithEmailAndPassword(auth, voter1Email, "Password123!");
    try {
      await castVoteFn({ organizationId: orgId1, eventId: futureEventId, candidateId: futureCandId });
      reportFail("Test 1: Event Not Started allowed vote.");
    } catch (e) {
      e.message.includes("has not opened yet") ? reportPass("Test 1: Event Not Started (Rejected correctly).") : reportFail(`Test 1: ${e.message}`);
    }

    // Test 2: Event ended
    try {
      await castVoteFn({ organizationId: orgId1, eventId: pastEventId, candidateId: pastCandId });
      reportFail("Test 2: Event Ended allowed vote.");
    } catch (e) {
      e.message.includes("window has closed") ? reportPass("Test 2: Event Ended (Rejected correctly).") : reportFail(`Test 2: ${e.message}`);
    }

    // Test 3: Inactive membership
    await adminDb.collection("organizationMembers").doc(`${orgId1}_${voter1Uid}`).update({ status: "suspended" });
    try {
      await castVoteFn({ organizationId: orgId1, eventId: eventId1, candidateId: cand1Id });
      reportFail("Test 3: Inactive membership allowed vote.");
    } catch (e) {
      e.message.includes("You do not have an active membership") ? reportPass("Test 3: Inactive Membership (Rejected correctly).") : reportFail(`Test 3: ${e.message}`);
    }
    await adminDb.collection("organizationMembers").doc(`${orgId1}_${voter1Uid}`).update({ status: "active" });

    // Test 4: SELECTED_DEPARTMENTS eligibility rejection
    try {
      await castVoteFn({ organizationId: orgId1, eventId: deptEventId, pollOptionId: opt1Id });
      reportFail("Test 4: SELECTED_DEPARTMENTS allowed vote for non-dept member.");
    } catch (e) {
      e.message.includes("not assigned to an eligible department") ? reportPass("Test 4: SELECTED_DEPARTMENTS (Rejected correctly).") : reportFail(`Test 4: ${e.message}`);
    }

    // Test 5: SELECTED_MEMBERS eligibility rejection
    try {
      await castVoteFn({ organizationId: orgId1, eventId: selMembersEventId, pollOptionId: selOpt1Id });
      reportFail("Test 5: SELECTED_MEMBERS allowed vote for non-selected member.");
    } catch (e) {
      e.message.includes("not on the eligible voters list") ? reportPass("Test 5: SELECTED_MEMBERS (Rejected correctly).") : reportFail(`Test 5: ${e.message}`);
    }

    // Test 6: Cross-organization event rejection
    try {
      await castVoteFn({ organizationId: orgId1, eventId: eventId2, candidateId: cand2Id });
      reportFail("Test 6: Cross-Organization Event allowed vote.");
    } catch (e) {
      e.message.includes("Voting event belongs to a different organization") ? reportPass("Test 6: Cross-Organization Event (Rejected correctly).") : reportFail(`Test 6: ${e.message}`);
    }

    // Test 7: Cross-organization candidate rejection
    try {
      await castVoteFn({ organizationId: orgId1, eventId: eventId1, candidateId: cand2Id });
      reportFail("Test 7: Cross-Organization Candidate allowed vote.");
    } catch (e) {
      e.message.includes("Candidate ownership metadata mismatch") ? reportPass("Test 7: Cross-Organization Candidate (Rejected correctly).") : reportFail(`Test 7: ${e.message}`);
    }

    // Test 8: Wrong choice type for event (candidateId passed to SINGLE_CHOICE_POLL)
    try {
      await castVoteFn({ organizationId: orgId1, eventId: allMembersPollEventId, candidateId: cand1Id });
      reportFail("Test 8: Candidate choice allowed on Single Choice Poll.");
    } catch (e) {
      e.message.includes("SINGLE_CHOICE_POLL requires a pollOptionId") ? reportPass("Test 8: Wrong Choice Type (Rejected correctly).") : reportFail(`Test 8: ${e.message}`);
    }

    // Test 9: Both choice types supplied
    try {
      await castVoteFn({ organizationId: orgId1, eventId: eventId1, candidateId: cand1Id, pollOptionId: opt1Id });
      reportFail("Test 9: Both choice types allowed vote.");
    } catch (e) {
      e.message.includes("Cannot supply both candidateId and pollOptionId") ? reportPass("Test 9: Both Choice Types (Rejected correctly).") : reportFail(`Test 9: ${e.message}`);
    }

    // Test 10: Neither choice supplied
    try {
      await castVoteFn({ organizationId: orgId1, eventId: eventId1 });
      reportFail("Test 10: Empty choice allowed vote.");
    } catch (e) {
      e.message.includes("must contain either candidateId or pollOptionId") ? reportPass("Test 10: Neither Choice Supplied (Rejected correctly).") : reportFail(`Test 10: ${e.message}`);
    }

    // Test 11: Malformed organizationId / eventId
    try {
      await castVoteFn({ organizationId: "   ", eventId: eventId1, candidateId: cand1Id });
      reportFail("Test 11: Malformed orgId allowed vote.");
    } catch (e) {
      e.message.includes("Valid organizationId is required") ? reportPass("Test 11: Malformed organizationId (Rejected correctly).") : reportFail(`Test 11: ${e.message}`);
    }

    // Test 12: Invalid YES/NO Option
    try {
      await castVoteFn({ organizationId: orgId1, eventId: yesNoEventId, pollOptionId: "invalid_yes_no_opt" });
      reportFail("Test 12: Random option allowed on YES_NO_POLL.");
    } catch (e) {
      e.message.includes("accepts ONLY generated") ? reportPass("Test 12: Invalid YES/NO Option (Rejected correctly).") : reportFail(`Test 12: ${e.message}`);
    }

    // =========================================================================
    // 2. FORGED IDENTITY / TIMESTAMP TEST
    // =========================================================================
    try {
      const forgedResult = await castVoteFn({
        organizationId: orgId1,
        eventId: eventId1,
        candidateId: cand1Id,
        userId: "forged_hacker_uid",
        voterId: "forged_hacker_voter_id",
        votedAt: "1999-01-01T00:00:00.000Z",
        castAt: "1999-01-01T00:00:00.000Z",
        receiptId: "forged_receipt_id",
        receiptHash: "forged_receipt_hash"
      });

      if (forgedResult.data.status === 'success') {
        const partSnap = await adminDb.collection("participation").doc(`${orgId1}_${eventId1}_${voter1Uid}`).get();
        if (!partSnap.exists || partSnap.data().userId !== voter1Uid) {
          reportFail("Test 13: Forged identity compromised participation document!");
        } else {
          const votesSnap = await adminDb.collection("votes").where("votingEventId", "==", eventId1).get();
          let voteClean = true;
          votesSnap.forEach(d => {
             if (d.data().userId === "forged_hacker_uid" || d.data().castAt === "1999-01-01T00:00:00.000Z") voteClean = false;
          });

          const receiptSnap = await adminDb.collection("voteReceipts").where("userId", "==", voter1Uid).get();
          let receiptClean = true;
          receiptSnap.forEach(d => {
             if (d.id === "forged_receipt_id" || d.data().receiptHash === "forged_receipt_hash") receiptClean = false;
          });

          if (voteClean && receiptClean) {
             reportPass("Test 13: Forged userId/votedAt/receipt parameters were COMPLETELY IGNORED by the server.");
          } else {
             reportFail("Test 13: Forged payload compromised votes or receipts collection.");
          }
        }
      }
    } catch(e) {
      reportFail(`Test 13 failed unexpectedly: ${e.message}`);
    }

    // =========================================================================
    // 3. CONCURRENT DUPLICATE SUBMISSION RACE CONDITION
    // =========================================================================
    await signInWithEmailAndPassword(auth, voter2Email, "Password123!");
    const p1 = castVoteFn({ organizationId: orgId1, eventId: eventId1, candidateId: cand1Id });
    const p2 = castVoteFn({ organizationId: orgId1, eventId: eventId1, candidateId: cand1Id });

    const raceResults = await Promise.allSettled([p1, p2]);
    const fulfilled = raceResults.filter(r => r.status === 'fulfilled');
    const rejected = raceResults.filter(r => r.status === 'rejected');

    if (fulfilled.length === 1 && rejected.length === 1) {
      reportPass("Test 14: Race condition handled atomically! 1 success, 1 rejection.");
    } else {
      reportFail(`Test 14: Race condition check failed. Fulfilled: ${fulfilled.length}, Rejected: ${rejected.length}`);
    }

    // =========================================================================
    // 4. CLIENT FIRESTORE SECURITY RULES (CREATE + UPDATE + DELETE DENIALS)
    // =========================================================================
    await adminDb.collection("votes").doc("fixture_vote_id").set({ organizationId: orgId1, votingEventId: eventId1, candidateId: cand1Id });
    await adminDb.collection("participation").doc("fixture_part_id").set({ organizationId: orgId1, votingEventId: eventId1, userId: voter1Uid });
    await adminDb.collection("voteReceipts").doc("fixture_receipt_id").set({ organizationId: orgId1, votingEventId: eventId1, userId: voter1Uid });
    await adminDb.collection("auditLogs").doc("fixture_audit_id").set({ organizationId: orgId1, action: "FIXTURE" });

    const collectionsToTest = [
      { name: "votes", docId: "fixture_vote_id" },
      { name: "participation", docId: "fixture_part_id" },
      { name: "voteReceipts", docId: "fixture_receipt_id" },
      { name: "auditLogs", docId: "fixture_audit_id" }
    ];

    for (const item of collectionsToTest) {
      const colName = item.name;
      const targetDocId = item.docId;

      try {
        await addDoc(collection(db, colName), { organizationId: orgId1, test: "client_create" });
        reportFail(`Test Client CREATE: Direct write to '${colName}' allowed!`);
      } catch (e) {
        e.code === 'permission-denied' ? reportPass(`Test Client CREATE: '${colName}' DENIED.`) : reportFail(`Unexpected error on '${colName}' CREATE: ${e.code}`);
      }

      try {
        await updateDoc(doc(db, colName, targetDocId), { hacked: true });
        reportFail(`Test Client UPDATE: Direct update on '${colName}' allowed!`);
      } catch (e) {
        e.code === 'permission-denied' ? reportPass(`Test Client UPDATE: '${colName}' DENIED.`) : reportFail(`Unexpected error on '${colName}' UPDATE: ${e.code}`);
      }

      try {
        await deleteDoc(doc(db, colName, targetDocId));
        reportFail(`Test Client DELETE: Direct delete on '${colName}' allowed!`);
      } catch (e) {
        e.code === 'permission-denied' ? reportPass(`Test Client DELETE: '${colName}' DENIED.`) : reportFail(`Unexpected error on '${colName}' DELETE: ${e.code}`);
      }
    }

  } catch (error) {
    console.error(`❌ FATAL SCRIPT ERROR: ${error.message}`);
    process.exit(1);
  }

  console.log(`\n=== TEST SUMMARY ===`);
  console.log(`PASS: ${passCount}`);
  console.log(`FAIL: ${failCount}`);
  console.log(`TOTAL: ${passCount + failCount}`);

  if (failCount > 0) {
    console.log("\n❌ TEST SUITE FAILED.");
    process.exit(1);
  } else {
    console.log("\n✅ ALL TESTS PASSED SUCCESSFULLY.");
    process.exit(0);
  }
}

runM5Step1HardeningTests();
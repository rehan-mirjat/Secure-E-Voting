const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, collection, query, where, getDocs, updateDoc, deleteDoc, addDoc } = require('firebase/firestore');

let testEnv;

before(async function() {
  this.timeout(10000);
  testEnv = await initializeTestEnvironment({
    projectId: "vote-d1ae4-rules-m5",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: readFileSync("../firestore.rules", "utf8"),
    }
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Setup Firestore Mock Data using admin context
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Org 1 Data
    await setDoc(doc(db, "organizations/org1"), { name: "Org 1", status: "active" });
    await setDoc(doc(db, "organizationMembers/org1_owner1"), { organizationId: "org1", userId: "owner1", role: "owner", status: "active" });
    await setDoc(doc(db, "organizationMembers/org1_member1"), { organizationId: "org1", userId: "member1", role: "member", status: "active" });
    await setDoc(doc(db, "departments/dept1"), { organizationId: "org1", name: "Dept 1" });

    // Org 1 Events
    await setDoc(doc(db, "votingEvents/org1_draft"), { organizationId: "org1", status: "DRAFT" });
    await setDoc(doc(db, "votingEvents/org1_active"), { organizationId: "org1", status: "ACTIVE" });
    await setDoc(doc(db, "votingEvents/org1_closed"), { organizationId: "org1", status: "CLOSED" });

    // Org 1 Candidates / Options
    await setDoc(doc(db, "candidates/cand1_active"), { organizationId: "org1", votingEventId: "org1_active" });
    await setDoc(doc(db, "candidates/cand1_draft"), { organizationId: "org1", votingEventId: "org1_draft" });
    await setDoc(doc(db, "pollOptions/opt1_active"), { organizationId: "org1", votingEventId: "org1_active" });

    // Org 2 Data
    await setDoc(doc(db, "organizations/org2"), { name: "Org 2", status: "active" });
    await setDoc(doc(db, "organizationMembers/org2_member2"), { organizationId: "org2", userId: "member2", role: "member", status: "active" });
    await setDoc(doc(db, "votingEvents/org2_active"), { organizationId: "org2", status: "ACTIVE" });
    await setDoc(doc(db, "candidates/cand2_active"), { organizationId: "org2", votingEventId: "org2_active" });
    await setDoc(doc(db, "departments/dept2"), { organizationId: "org2", name: "Dept 2" });

    // Users
    await setDoc(doc(db, "users/owner1"), { firstName: "Owner", lastName: "One", role: "should_not_change" });
    await setDoc(doc(db, "users/member1"), { firstName: "Member", lastName: "One" });

    // Participation
    await setDoc(doc(db, "participation/part1"), { organizationId: "org1", userId: "member1" });
    await setDoc(doc(db, "participation/part2"), { organizationId: "org2", userId: "member2" });

    // Secret Data
    await setDoc(doc(db, "votes/vote1"), { candidateId: "cand1_active" });
    await setDoc(doc(db, "voteReceipts/receipt1"), { userId: "member1" });
    await setDoc(doc(db, "auditLogs/log1"), { action: "TEST" });
  });
});

after(async function() {
  this.timeout(5000);
  if (testEnv) await testEnv.cleanup();
});

describe("M5 Firestore Rules Hardening", () => {

  describe("1. Query Compatibility", () => {
    it("active member can query ACTIVE events in their org", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      const q = query(collection(db, "votingEvents"), where("organizationId", "==", "org1"), where("status", "==", "ACTIVE"));
      await assertSucceeds(getDocs(q));
    });

    it("active member CANNOT query DRAFT events in their org", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      const q = query(collection(db, "votingEvents"), where("organizationId", "==", "org1"), where("status", "==", "DRAFT"));
      await assertFails(getDocs(q));
    });

    it("admin can query ALL events in their org", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      const q = query(collection(db, "votingEvents"), where("organizationId", "==", "org1"));
      await assertSucceeds(getDocs(q));
    });
  });

  describe("2. isSuperAdmin Hardening", () => {
    it("super admin with explicit claim can read events", async () => {
      const db = testEnv.authenticatedContext("super", { platformAdmin: true }).firestore();
      await assertSucceeds(getDoc(doc(db, "votingEvents/org1_draft")));
    });

    it("user without explicit claim is denied", async () => {
      const db = testEnv.authenticatedContext("fake_super", { platformAdmin: false }).firestore();
      await assertFails(getDoc(doc(db, "votingEvents/org1_draft")));
    });
  });

  describe("3. Tenant Consistency & Cross-Org Tests", () => {
    it("member of Org 1 cannot read Org 2 data", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(getDoc(doc(db, "organizations/org2")));
      await assertFails(getDoc(doc(db, "votingEvents/org2_active")));
      await assertFails(getDoc(doc(db, "candidates/cand2_active")));
      await assertFails(getDoc(doc(db, "departments/dept2")));
      await assertFails(getDoc(doc(db, "participation/part2")));
    });

    it("unauthenticated cannot read anything", async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(db, "organizations/org1")));
    });
  });

  describe("4. Voting Privacy", () => {
    it("normal member cannot read votes", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(getDoc(doc(db, "votes/vote1")));
    });

    it("admin cannot read votes", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(getDoc(doc(db, "votes/vote1")));
    });

    it("normal member cannot write votes", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(addDoc(collection(db, "votes"), {}));
    });

    it("normal member cannot write participation", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(setDoc(doc(db, "participation/newpart"), {}));
    });

    it("normal member cannot write voteReceipts", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(setDoc(doc(db, "voteReceipts/newrec"), {}));
    });

    it("normal member cannot read another user's participation", async () => {
      const db = testEnv.authenticatedContext("member2").firestore(); // Not member1
      await assertFails(getDoc(doc(db, "participation/part1"))); // part1 belongs to member1
    });

    it("admin cannot read another user's participation", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(getDoc(doc(db, "participation/part1"))); // SRS doesn't grant admins direct query access
    });

    it("audit logs remain client inaccessible", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(getDoc(doc(db, "auditLogs/log1")));
    });

    it("vote receipts cannot be read by other users", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(getDoc(doc(db, "voteReceipts/receipt1")));
    });
  });

  describe("5. User Profile Security", () => {
    it("user can update allowed cosmetic fields", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertSucceeds(updateDoc(doc(db, "users/owner1"), { firstName: "NewOwner" }));
    });

    it("user CANNOT update protected fields (role)", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(updateDoc(doc(db, "users/owner1"), { role: "superadmin" }));
    });

    it("user CANNOT update another user's profile", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(updateDoc(doc(db, "users/owner1"), { firstName: "Hacked" }));
    });
  });

  describe("7 & 8. Status-Based Event & Candidate Access", () => {
    it("regular member allowed ACTIVE/CLOSED events", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertSucceeds(getDoc(doc(db, "votingEvents/org1_active")));
      await assertSucceeds(getDoc(doc(db, "votingEvents/org1_closed")));
      await assertSucceeds(getDoc(doc(db, "candidates/cand1_active")));
    });

    it("regular member denied DRAFT events & candidates", async () => {
      const db = testEnv.authenticatedContext("member1").firestore();
      await assertFails(getDoc(doc(db, "votingEvents/org1_draft")));
      await assertFails(getDoc(doc(db, "candidates/cand1_draft")));
    });

    it("admin allowed DRAFT events & candidates", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertSucceeds(getDoc(doc(db, "votingEvents/org1_draft")));
      await assertSucceeds(getDoc(doc(db, "candidates/cand1_draft")));
    });
  });

  describe("9. Default-Deny Verification", () => {
    it("unknown collections are denied", async () => {
      const db = testEnv.authenticatedContext("owner1").firestore();
      await assertFails(getDoc(doc(db, "unknown/doc")));
      await assertFails(setDoc(doc(db, "unknown/doc"), {}));
    });
  });
});

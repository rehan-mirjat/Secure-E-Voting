const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, deleteObject, getBytes } = require('firebase/storage');

let testEnv;

before(async function() {
  this.timeout(10000);
  testEnv = await initializeTestEnvironment({
    projectId: "vote-d1ae4-storage-avatar",
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: readFileSync("../storage.rules", "utf8"),
    }
  });
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

after(async function() {
  this.timeout(5000);
  if (testEnv) await testEnv.cleanup();
});

const smallJpeg = new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01]);
const exact500KbJpeg = new Uint8Array(512000); // Exactly 500 KB (512,000 bytes)
exact500KbJpeg[0] = 0xFF; exact500KbJpeg[1] = 0xD8;
const largeJpeg = new Uint8Array(600 * 1024); // 600KB (> 500KB)
const smallPng = new Uint8Array([0x89, 0x50, 0x4E, 0x47]);

describe("User Profile Photo Storage Rules", function() {
  this.timeout(10000);

  it("PASS: user uploads own profile photo", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertSucceeds(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });

  it("PASS: user uploads exactly 500 KB photo (512000 bytes inclusive)", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertSucceeds(uploadBytes(storageRef, exact500KbJpeg, { contentType: "image/jpeg" }));
  });

  it("PASS: user replaces own profile photo", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
      await uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" });
    });

    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertSucceeds(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });

  it("PASS: user reads own profile photo", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
      await uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" });
    });

    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertSucceeds(getBytes(storageRef));
  });

  // DENIED CASES
  it("DENIED: user uploads to another user's path", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/otherUser/profile/avatar.jpg");
    await assertFails(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });

  it("DENIED: user replaces another user's photo", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const storageRef = ref(context.storage(), "users/otherUser/profile/avatar.jpg");
      await uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" });
    });

    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/otherUser/profile/avatar.jpg");
    await assertFails(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });

  it("DENIED: unauthenticated upload", async () => {
    const context = testEnv.unauthenticatedContext();
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertFails(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });

  it("DENIED: invalid content type (PNG)", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertFails(uploadBytes(storageRef, smallPng, { contentType: "image/png" }));
  });

  it("DENIED: oversized file (>500KB)", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/profile/avatar.jpg");
    await assertFails(uploadBytes(storageRef, largeJpeg, { contentType: "image/jpeg" }));
  });

  it("DENIED: arbitrary storage path", async () => {
    const context = testEnv.authenticatedContext("user123");
    const storageRef = ref(context.storage(), "users/user123/arbitrary.jpg");
    await assertFails(uploadBytes(storageRef, smallJpeg, { contentType: "image/jpeg" }));
  });
});

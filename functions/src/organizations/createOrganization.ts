import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const ALLOWED_TYPES = ["academic", "corporate", "nonProfit", "club", "community", "other"];
const URL_REGEX = /^https:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(\/.*)?$/;
const EMAIL_REGEX = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
const UUID_V4_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const createOrganization = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated to create an organization.");
  }

  const uid = request.auth.uid;
  const db = getFirestore();

  // 2. Validate authenticated user's profile and account state in Firestore
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError("permission-denied", "User profile does not exist.");
  }

  const userData = userSnap.data();
  if (!userData || userData.status !== "active") {
    throw new HttpsError("permission-denied", "Your account must be active to create an organization.");
  }

  // 3. Extract and validate payload
  const {
    requestId,
    name,
    type,
    description,
    email,
    country,
    city,
    website,
    logoUrl,
  } = request.data || {};

  // Validate requestId (Must be valid UUID v4 format)
  if (!requestId || typeof requestId !== "string" || !UUID_V4_REGEX.test(requestId.trim())) {
    throw new HttpsError("invalid-argument", "Valid UUID v4 requestId string is required for idempotency.");
  }

  const cleanRequestId = requestId.trim().toLowerCase();

  // Validate Organization Name
  if (!name || typeof name !== "string" || name.trim().length < 3 || name.trim().length > 100) {
    throw new HttpsError("invalid-argument", "Organization name must be between 3 and 100 characters.");
  }

  // Validate Controlled Organization Type Vocabulary
  if (!type || typeof type !== "string" || !ALLOWED_TYPES.includes(type.trim())) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid organization type. Allowed values: ${ALLOWED_TYPES.join(", ")}`
    );
  }

  // Validate Description
  if (description && (typeof description !== "string" || description.trim().length > 500)) {
    throw new HttpsError("invalid-argument", "Description cannot exceed 500 characters.");
  }

  // Validate Contact Email Syntax
  if (!email || typeof email !== "string" || !EMAIL_REGEX.test(email.trim())) {
    throw new HttpsError("invalid-argument", "A valid contact email address is required.");
  }

  // Validate Country and City
  if (!country || typeof country !== "string" || country.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Country is required.");
  }

  if (!city || typeof city !== "string" || city.trim().length === 0) {
    throw new HttpsError("invalid-argument", "City is required.");
  }

  // Validate Optional URLs (must be valid HTTPS)
  if (website && (typeof website !== "string" || !URL_REGEX.test(website.trim()))) {
    throw new HttpsError("invalid-argument", "Website must be a valid HTTPS URL (e.g. https://domain.com).");
  }

  if (logoUrl && (typeof logoUrl !== "string" || !URL_REGEX.test(logoUrl.trim()))) {
    throw new HttpsError("invalid-argument", "Logo URL must be a valid HTTPS URL.");
  }

  const trimmedName = name.trim();
  const trimmedType = type.trim();
  const trimmedDescription = (description || "").trim();
  const trimmedEmail = email.trim();
  const trimmedCountry = country.trim();
  const trimmedCity = city.trim();
  const cleanWebsite = website ? website.trim() : null;
  const cleanLogoUrl = logoUrl ? logoUrl.trim() : null;

  // 4. Transactional Idempotency Claiming and Document Creation
  try {
    const createdOrgId = await db.runTransaction(async (transaction) => {
      const idempotencyRef = db.collection("organizationIdempotency").doc(cleanRequestId);
      const idempotencySnap = await transaction.get(idempotencyRef);

      // Check if this requestId was already processed
      if (idempotencySnap.exists) {
        const idData = idempotencySnap.data();
        if (idData && idData.actorUid !== uid) {
          // Cross-user reuse attempt: REJECT without revealing existing org ID
          throw new HttpsError("permission-denied", "Access denied.");
        }
        // Identical request from same user: Return previously generated organizationId
        return idData?.organizationId as string;
      }

      // Generate Firestore Auto-ID for Organization
      const orgRef = db.collection("organizations").doc();
      const orgId = orgRef.id;

      const membershipRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
      const auditRef = db.collection("auditLogs").doc();

      // Write 1: Organization Document
      transaction.set(orgRef, {
        id: orgId,
        name: trimmedName,
        type: trimmedType,
        description: trimmedDescription,
        email: trimmedEmail,
        website: cleanWebsite,
        logoUrl: cleanLogoUrl,
        country: trimmedCountry,
        city: trimmedCity,
        status: "pending",
        ownerId: uid,
        createdAt: FieldValue.serverTimestamp(),
        verifiedAt: null,
        suspendedAt: null,
      });

      // Write 2: Organization Member Document (Owner)
      transaction.set(membershipRef, {
        membershipId: `${orgId}_${uid}`,
        organizationId: orgId,
        userId: uid,
        role: "owner",
        status: "active",
        employeeId: null,
        departmentId: null,
        joinedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Write 3: Audit Log Document
      transaction.set(auditRef, {
        organizationId: orgId,
        actorUid: uid,
        action: "CREATE_ORGANIZATION",
        resourceType: "organization",
        resourceId: orgId,
        metadata: {
          organizationName: trimmedName,
          type: trimmedType,
        },
        timestamp: FieldValue.serverTimestamp(),
      });

      // Write 4: Idempotency Claim Record
      transaction.set(idempotencyRef, {
        requestId: cleanRequestId,
        actorUid: uid,
        organizationId: orgId,
        createdAt: FieldValue.serverTimestamp(),
      });

      return orgId;
    });

    return { status: "success", organizationId: createdOrgId };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to create organization.", error);
  }
});

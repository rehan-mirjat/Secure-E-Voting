import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const URL_REGEX = /^https:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(\/.*)?$/;

export const updateOrganization = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated to update an organization.");
  }

  const uid = request.auth.uid;
  const db = getFirestore();

  const { organizationId, description, website, logoUrl } = request.data || {};

  if (!organizationId || typeof organizationId !== "string" || organizationId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid organizationId is required.");
  }

  const orgId = organizationId.trim();

  // 2. Branding and organization metadata are Owner-managed in the SRS.
  const memberRef = db.collection("organizationMembers").doc(`${orgId}_${uid}`);
  const memberSnap = await memberRef.get();

  if (!memberSnap.exists || memberSnap.data()?.status !== "active" ||
      memberSnap.data()?.organizationId !== orgId || memberSnap.data()?.userId !== uid) {
    throw new HttpsError("permission-denied", "You must be an active member of this organization.");
  }

  const role = memberSnap.data()?.role;
  if (role !== "owner") {
    throw new HttpsError("permission-denied", "Only the Organization Owner can update organization settings.");
  }

  // 3. Validate cosmetic fields
  const updates: Record<string, any> = {};

  if (description !== undefined) {
    if (description !== null && (typeof description !== "string" || description.trim().length > 500)) {
      throw new HttpsError("invalid-argument", "Description cannot exceed 500 characters.");
    }
    updates.description = description ? description.trim() : "";
  }

  if (website !== undefined) {
    if (website !== null && typeof website !== "string") {
      throw new HttpsError("invalid-argument", "Website must be a valid HTTPS URL.");
    }
    if (typeof website === "string" && website.trim().length > 0) {
      if (!URL_REGEX.test(website.trim())) {
        throw new HttpsError("invalid-argument", "Website must be a valid HTTPS URL.");
      }
      updates.website = website.trim();
    } else {
      updates.website = null;
    }
  }

  if (logoUrl !== undefined) {
    if (logoUrl !== null && typeof logoUrl !== "string") {
      throw new HttpsError("invalid-argument", "Logo URL must be a valid HTTPS URL.");
    }
    if (typeof logoUrl === "string" && logoUrl.trim().length > 0) {
      if (!URL_REGEX.test(logoUrl.trim())) {
        throw new HttpsError("invalid-argument", "Logo URL must be a valid HTTPS URL.");
      }
      updates.logoUrl = logoUrl.trim();
    } else {
      updates.logoUrl = null;
    }
  }

  if (Object.keys(updates).length === 0) {
    return { status: "success", message: "No fields to update." };
  }

  updates.updatedAt = FieldValue.serverTimestamp();

  try {
    await db.collection("organizations").doc(orgId).update(updates);

    // Audit Log
    await db.collection("auditLogs").add({
      organizationId: orgId,
      actorUid: uid,
      action: "UPDATE_ORGANIZATION_METADATA",
      resourceType: "organization",
      resourceId: orgId,
      metadata: { updatedKeys: Object.keys(updates) },
      timestamp: FieldValue.serverTimestamp(),
    });

    return { status: "success", organizationId: orgId };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Failed to update organization metadata.", error);
  }
});

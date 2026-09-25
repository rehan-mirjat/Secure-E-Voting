import { Firestore, FieldValue, Timestamp } from "firebase-admin/firestore";

export interface TallyRow {
  choiceId: string;
  choiceType: string;
  name: string;
  votes: number;
  percent: number;
}

export interface EventResultsPayload {
  organizationId: string;
  votingEventId: string;
  published: boolean;
  publishedAt: FirebaseFirestore.Timestamp | null;
  publishedBy: string | null;
  calculatedAt: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
  calculatedBy: string;
  totalVotes: number;
  eligibleCount: number;
  participationCount: number;
  turnoutPercent: number;
  tallies: TallyRow[];
}

export async function countEligibleVoters(
  db: Firestore,
  organizationId: string,
  eventData: FirebaseFirestore.DocumentData
): Promise<number> {
  const eligibilityType = eventData.eligibilityType || "ALL_MEMBERS";

  if (eligibilityType === "SELECTED_MEMBERS") {
    const ids: string[] = Array.isArray(eventData.eligibilityUserIds)
      ? eventData.eligibilityUserIds
      : [];
    if (ids.length === 0) return 0;
    const snap = await db
      .collection("organizationMembers")
      .where("organizationId", "==", organizationId)
      .where("status", "==", "active")
      .get();
    const eligibleIds = new Set(ids);
    return snap.docs.filter((doc) => eligibleIds.has(doc.data()?.userId)).length;
  }

  if (eligibilityType === "SELECTED_DEPARTMENTS") {
    const deptIds: string[] = Array.isArray(eventData.eligibilityDepartmentIds)
      ? eventData.eligibilityDepartmentIds
      : [];
    if (deptIds.length === 0) return 0;
    const snap = await db
      .collection("organizationMembers")
      .where("organizationId", "==", organizationId)
      .where("status", "==", "active")
      .get();
    return snap.docs.filter((doc) => deptIds.includes(doc.data()?.departmentId)).length;
  }

  const snap = await db
    .collection("organizationMembers")
    .where("organizationId", "==", organizationId)
    .where("status", "==", "active")
    .get();
  return snap.size;
}

export async function calculateEventResults(
  db: Firestore,
  eventId: string,
  actorUid: string,
  options?: { publish?: boolean }
): Promise<EventResultsPayload> {
  const eventSnap = await db.collection("votingEvents").doc(eventId).get();
  if (!eventSnap.exists) {
    throw new Error("NOT_FOUND");
  }
  const eventData = eventSnap.data()!;
  const organizationId = eventData.organizationId as string;
  const status = eventData.status as string;

  if (status !== "CLOSED" && status !== "ARCHIVED") {
    throw new Error("NOT_CLOSED");
  }

  const [votesSnap, participationSnap, candidatesSnap, optionsSnap, existingResults] = await Promise.all([
    db.collection("votes").where("votingEventId", "==", eventId).where("organizationId", "==", organizationId).get(),
    db.collection("participation").where("votingEventId", "==", eventId).where("organizationId", "==", organizationId).get(),
    db.collection("candidates").where("votingEventId", "==", eventId).where("organizationId", "==", organizationId).get(),
    db.collection("pollOptions").where("votingEventId", "==", eventId).where("organizationId", "==", organizationId).get(),
    db.collection("eventResults").doc(eventId).get(),
  ]);

  const existingData = existingResults.data();
  // Published tallies are a public record. Recalculation must never silently
  // change results that members have already seen.
  if (existingData?.published === true) return existingData as EventResultsPayload;

  const counts = new Map<string, number>();
  for (const doc of votesSnap.docs) {
    const choiceId = (doc.data()?.choiceId as string) || "";
    if (!choiceId) continue;
    counts.set(choiceId, (counts.get(choiceId) || 0) + 1);
  }

  const roster: Array<{ choiceId: string; choiceType: string; name: string }> = [];
  for (const doc of candidatesSnap.docs) {
    const data = doc.data();
    roster.push({
      choiceId: doc.id,
      choiceType: "CANDIDATE",
      name: (data.name as string) || "Candidate",
    });
  }
  for (const doc of optionsSnap.docs) {
    const data = doc.data();
    roster.push({
      choiceId: doc.id,
      choiceType: "POLL_OPTION",
      name: (data.label as string) || (data.name as string) || "Option",
    });
  }

  const totalVotes = Array.from(counts.values()).reduce((sum, count) => sum + count, 0);
  const tallies: TallyRow[] = roster.map((row) => {
    const votes = counts.get(row.choiceId) || 0;
    return {
      ...row,
      votes,
      percent: totalVotes === 0 ? 0 : Math.round((votes / totalVotes) * 10000) / 100,
    };
  });

  tallies.sort((a, b) => b.votes - a.votes || a.name.localeCompare(b.name));

  const eligibleCount = await countEligibleVoters(db, organizationId, eventData);
  const participationCount = participationSnap.size;
  const turnoutPercent =
    eligibleCount === 0 ? 0 : Math.round((participationCount / eligibleCount) * 10000) / 100;

  const alreadyPublished = existingResults.exists && existingResults.data()?.published === true;
  const published = options?.publish === true || alreadyPublished;

  const payload: EventResultsPayload = {
    organizationId,
    votingEventId: eventId,
    published,
    publishedAt: alreadyPublished
      ? (existingResults.data()?.publishedAt as Timestamp) || null
      : options?.publish
        ? (Timestamp.now() as Timestamp)
        : null,
    publishedBy: alreadyPublished
      ? (existingResults.data()?.publishedBy as string) || null
      : options?.publish
        ? actorUid
        : null,
    calculatedAt: FieldValue.serverTimestamp(),
    calculatedBy: actorUid,
    totalVotes,
    eligibleCount,
    participationCount,
    turnoutPercent,
    tallies,
  };

  await db.collection("eventResults").doc(eventId).set(payload, { merge: true });
  return payload;
}

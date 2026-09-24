import * as crypto from "crypto";

export interface ReceiptGenerationResult {
  receiptId: string;
  receiptHash: string;
  serverSalt: string;
}

/**
 * Generates a non-coercive vote receipt hash.
 * Crucially EXCLUDES candidateId / pollOptionId to preserve ballot secrecy
 * and prevent voter-coercion/vote-selling schemes.
 * Uses a cryptographically strong server-generated salt.
 */
export function generateVoteReceipt(
  organizationId: string,
  eventId: string,
  userId: string,
  timestampMillis: number
): ReceiptGenerationResult {
  const serverSalt = crypto.randomBytes(16).toString("hex");
  const rawPayload = `${organizationId}:${eventId}:${userId}:${timestampMillis}:${serverSalt}`;
  const receiptHash = crypto.createHash("sha256").update(rawPayload).digest("hex");

  return {
    receiptId: crypto.randomUUID(),
    receiptHash,
    serverSalt,
  };
}

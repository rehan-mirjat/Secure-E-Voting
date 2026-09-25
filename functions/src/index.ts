import { onCall } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();

// Set global options to minimize Cloud Run CPU quota requirements on new projects.
setGlobalOptions({ maxInstances: 1 });

/**
 * Milestone 1: Diagnostics Ping
 * A simple callable function to verify that the Flutter client
 * can successfully communicate with Firebase Cloud Functions (or Emulator).
 */
export const ping = onCall((request) => {
  return {
    status: "success",
    message: "pong",
    timestamp: new Date().toISOString(),
  };
});

export * from "./auth/completeRegistration";
export * from "./organizations/createOrganization";
export * from "./membership/createJoiningCode";
export * from "./membership/joinOrganizationWithCode";
export * from "./membership/revokeJoiningCode";
export * from "./membership/inviteMember";
export * from "./membership/acceptInvitation";
export * from "./membership/revokeInvitation";
export * from "./membership/getPendingInvitations";
export * from "./departments/createDepartment";
export * from "./departments/updateDepartment";
export * from "./departments/deleteDepartment";
export * from "./departments/assignMemberToDepartment";
export * from "./departments/removeMemberFromDepartment";
export * from "./membership/getOrganizationMembers";
export * from "./membership/updateMemberRole";
export * from "./membership/updateMemberStatus";
export * from "./membership/removeMember";
export * from "./membership/leaveOrganization";
export * from "./voting_events/createVotingEvent";
export * from "./voting_events/updateVotingEvent";
export * from "./voting_events/publishVotingEvent";
export * from "./voting_events/closeVotingEvent";
export * from "./voting_events/cancelVotingEvent";
export * from "./voting_events/deleteVotingEvent";
export * from "./voting_events/evaluateVotingEventLifecycles";
export * from "./voting_events/createCandidate";
export * from "./voting_events/finalizeCandidatePhoto";
export * from "./voting_events/updateCandidate";
export * from "./voting_events/deleteCandidatePhoto";
export * from "./voting_events/deleteCandidate";
export * from "./voting_events/createPollOption";
export * from "./voting_events/updatePollOption";
export * from "./voting_events/deletePollOption";
export * from "./voting/castVote";
export * from "./voting/calculateResults";
export * from "./voting/publishResults";
export * from "./voting/getEventMonitoring";
export * from "./platform/listOrganizations";
export * from "./platform/reviewOrganization";

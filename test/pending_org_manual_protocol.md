# Milestone 4 - Pending Organization Defect Resolution QA

This document outlines the manual verification protocol required to confirm that a newly created `pending` organization is properly rendered, selectable, and persisted by the Riverpod state management layer within the Flutter Web UI.

## Instructions
1. Run the Flutter application locally (`flutter run -d chrome`).
2. Follow the steps below using a fresh test account.
3. Verify the expected results.

## Protocol Matrix

| ID | Action Required | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **Org-A.1** | Fill valid data & Submit | Success Snackbar appears. Navigates cleanly back to `/orgs` tab. | |
| **Org-A.2** | View `/orgs` tab post-submit | The newly created organization is instantly visible in the Organization List. | |
| **Org-A.3** | Active Context Check | The `OrganizationContextSwitcher` in the AppBar immediately shows the newly created Org name as Active. | |
| **Org-A.4** | Role Check | The Context Switcher displays the user role as `OWNER`. | |
| **Org-A.5** | Admin Navigation Check | Because the active org is the newly created one, the **Admin** tab is immediately visible and clickable in the `AppNavigationShell`. | |
| **Org-B.1** | Browser Refresh (`F5`) | Navigates back into the app. The newly created `pending` organization is automatically restored as the active context via `SharedPreferences` lookup. | |
| **Org-C.1** | Manual Status Mutation | Using Firebase Emulator UI, manually change the organization's `status` to `verified` in Firestore. | |
| **Org-C.2** | Re-verify Context | Refresh the browser. The active context successfully restores. The Organization List displays the `VERIFIED` status badge instead of `PENDING`. | |

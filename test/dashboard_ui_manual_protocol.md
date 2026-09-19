# Milestone 4 - Step 7: Manual UI Acceptance Protocol

This document outlines the formal manual acceptance protocol for the Step 7 UI requirements (14.1-14.19) that cannot be safely automated via mock widget tests.

## Instructions
1. Run the Flutter application and Firebase Emulators locally (`flutter run -d chrome`).
2. Follow the steps below using two test accounts:
   - `admin@securevote.com` (Owner/Admin in Org A)
   - `member@securevote.com` (Regular Member in Org A)
3. Check the "Result" column to verify expected behavior.

## Protocol Matrix

| ID | State | Action Required | Expected UI Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :--- |
| **14.1** | Auth: Admin | Navigate to `/admin/events` | Renders Dashboard successfully | |
| **14.2** | Auth: Member | Navigate to `/admin/events` | Instantly redirects to `/home` (Home/Election Feed), not `/admin/events`. | |
| **14.5** | Events: 0 | View Dashboard | Displays "No voting events found." graphic and "Create your first Voting Event" button | |
| **14.6** | Events: DRAFT | View Event Card | Shows "Delete", "Manage Choices", "Edit Config", "Publish" buttons | |
| **14.7** | Events: SCHEDULED | View Event Card | Shows "Cancel Event", "View Details". Editable config is hidden | |
| **14.8** | Events: ACTIVE | View Event Card | Shows "Close Early", "Monitor Turnout". Edit/Cancel are hidden | |
| **14.9** | Events: CLOSED | View Event Card | Shows "View Results" only | |
| **14.10** | Events: ARCHIVED | View Event Card | Shows "View Details" only | |
| **14.11** | Action: Monitor | Click "Monitor Turnout" | Displays M6 stub snackbar: "Monitor Turnout coming in Milestone 6" | |
| **14.12** | Action: Results | Click "View Results" | Displays M6 stub snackbar: "View Results coming in Milestone 6" | |
| **14.13** | Action: Delete | Click "Delete" on DRAFT | AlertDialog appears: "Delete Draft Event?". Clicking cancel aborts. | |
| **14.14** | Action: Publish | Click "Publish" on unready DRAFT | Screen displays specific warning depending on Event Type (e.g. requires 2 candidates, requires 2 poll options). Publish disabled | |
| **14.15** | Action: Cancel | Click "Cancel Event" on SCHEDULED | AlertDialog appears: "Cancel Scheduled Event?". Clicking cancel aborts. | |
| **14.16** | Action: Close | Click "Close Early" on ACTIVE | AlertDialog appears: "Close Event Early?". Clicking cancel aborts. | |
| **14.17** | Async Activity | Click "Confirm" on any dialog | Dialog dismisses, semi-transparent black loading overlay appears over dashboard while request is in flight | |
| **14.18** | Error Handling | Trigger manual `failed-precondition` | Loading overlay dismisses, red Snackbar appears: "Action unavailable" or safe error message | |
| **14.19** | Error Handling | Revoke Admin role in DB, try Delete | Server-side authorization blocks the request. Loading overlay dismisses, red Snackbar appears: "You do not have permission" | |

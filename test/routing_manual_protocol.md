# Milestone 4 QA: Post-Login Defect & Routing Protocol

This document outlines the formal manual acceptance protocol for routing and shell integration requirements (15.1-15.20) that cannot be safely automated due to `go_router` redirection lifecycle complexities.

## Instructions
1. Run the Flutter application locally (`flutter run -d chrome`).
2. Follow the steps below using fresh accounts.
3. Check the "Result" column to verify expected behavior.

## Protocol Matrix

| ID | Action Required | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **15.1** | Unauthenticated user types `http://localhost:<port>/home` | Redirects to `/login` | |
| **15.2** | User registers but doesn't verify email. Types `/home` | Redirects to `/verify-email` | |
| **15.3** | Verified user logs in | Success. Transitions to `/home` (Election Feed Screen) | |
| **15.4** | Logged-in verified user types `/login` in address bar | Instantly redirects back to `/home` | |
| **15.5** | Logged-in user with 0 orgs views `/home` | Screen displays "Welcome... You do not belong to any organizations" with a "Get Started" prompt | |
| **15.6** | Click "Sign Out" from `/settings` tab | App redirects back to `/login` | |
| **15.7** | Admin clicks "Admin" tab in navigation | Transitions cleanly to `/admin/events` Dashboard | |
| **15.8** | Member types `/admin/events` in address bar | Instantly redirects back to `/home` | |
| **15.9** | Cross-tenant Role Check: Create User A in Org 1 (Member) and Org 2 (Admin). Set Org 1 Active. Click Admin tab. | Tab is hidden; manual URL access redirects to `/home` | |
| **15.10** | Admin on `/admin/events`. Another user demotes them to Member in DB | Router refreshes on the fly, bumping user out to `/home` instantly | |
| **15.11** | User changes Org via AppBar dropdown | Nav shell refreshes. If new org role is member, Admin tab vanishes. Direct `/admin/events` access is rejected when new role is member. | |
| **15.12** | Unauthenticated user clicks a deep link to `/admin/events/new` | Redirects to `/login`. Upon successful login, checks role, forces `/home` if non-admin | |
| **15.13** | Member views UI Shell | Renders 3 items: Home, Orgs, Settings | |
| **15.14** | Admin views UI Shell | Renders 4 items: Home, Orgs, Settings, Admin | |
| **15.15** | Resize window width to < 600px | Navigation shifts from Rail to Bottom NavigationBar | |
| **15.16** | Resize window width to > 600px | Navigation shifts to left NavigationRail | |
| **15.17** | Click "Settings" tab | Renders `ProfileScreen` seamlessly inside the shell | |
| **15.18** | Auth/organization loading guard: Start the app while auth/org state is still loading | Router does not prematurely redirect to `/login` or `/home` based on incomplete state, and no unauthorized/admin UI is briefly exposed. | |

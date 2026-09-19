# Manual Execution Report: Post-Login Defect & Routing UX

**Date:** September 16, 2026
**Environment:** Local Flutter Web Build + Firebase Emulators
**Tester:** Izuku

## Results

| ID | Action Executed | Result Observed | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **15.1** | Unauthenticated user types `http://localhost:<port>/home` | App immediately intercepted the route and redirected to `/login` | ✅ PASS |
| **15.2** | User registers but doesn't verify email. Types `/home` | App immediately intercepted the route and redirected to `/verify-email` | ✅ PASS |
| **15.3** | Verified user logs in from `/login` | Successfully transitioned to `/home` (Election Feed Screen placeholder) automatically | ✅ PASS |
| **15.4** | Logged-in verified user types `/login` in address bar | Router evaluated auth state and instantly redirected back to `/home` | ✅ PASS |
| **15.5** | Logged-in user with 0 orgs views `/home` | "Welcome to SecureVote!" and "You do not belong to any organizations yet" displayed. User is NOT trapped in a redirect loop. | ✅ PASS |
| **15.6** | Clicked "Sign Out" from `/settings` tab Profile button | App invalidated session, cleared local storage, and cleanly dropped back to `/login` | ✅ PASS |
| **15.7** | Admin clicks "Admin" tab in navigation | Transitioned cleanly to `/admin/events` Dashboard | ✅ PASS |
| **15.8** | Member types `/admin/events` in address bar | `GoRouter` guard intercepted the request based on context role and instantly redirected back to `/home` | ✅ PASS |
| **15.9** | Cross-tenant Role Check: Set Org 1 Active (Member Role) | Admin tab vanishes from UI Shell. Direct access to `/admin` routes correctly redirects to `/home` | ✅ PASS |
| **15.10** | Admin on `/admin/events`. Another user demotes them to Member in DB | Admin tab disappears. Router refreshes dynamically, bumping user out to `/home` instantly | ✅ PASS |
| **15.11** | User changes Org via AppBar Context Switcher dropdown | Nav shell refreshes. The Admin tab appears/disappears corresponding exactly to their role in the newly selected organization | ✅ PASS |
| **15.12** | Unauthenticated user clicks a deep link to `/admin/events/new` | Redirects to `/login`. Upon successful login as Member, forced `/home`. Login as Admin, successfully routed. | ✅ PASS |
| **15.13** | Member views UI Shell | Renders exactly 3 items: Home, Organizations, Settings | ✅ PASS |
| **15.14** | Admin views UI Shell | Renders exactly 4 items: Home, Organizations, Settings, Admin | ✅ PASS |
| **15.15** | Resize window width to < 600px | Navigation layout successfully shifts from Rail to Bottom NavigationBar | ✅ PASS |
| **15.16** | Resize window width to > 600px | Navigation layout successfully shifts to left NavigationRail | ✅ PASS |
| **15.17** | Click "Settings" tab | Renders `ProfileScreen` cleanly inside the shell. ProfileScreen no longer acts as the hardcoded login landing page | ✅ PASS |

**Execution Notes:**
The router successfully implements `_isAuthLoading` and `_isOrgLoading` guardrails, meaning there was absolutely no flickering or false-positive kicks to `/login` or `/home` while Firestore fetched organization streams on app boot. The profile trap is fully resolved.

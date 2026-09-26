# SecureVote

SecureVote is a multi-tenant voting and polling application for organizations. The Flutter client targets Android, iOS, and web. Firebase Authentication handles identity; Cloud Functions enforce sensitive operations; Firestore stores application data; Cloud Storage stores approved images.

## Product scope

Version 1 supports:

- Organization registration, verification, branding, and organization switching.
- Organization owners, administrators, and members with organization-scoped roles.
- Member invitations, adding existing accounts, joining codes, and departments.
- Candidate elections, single-choice polls, and Yes/No polls.
- All-member, selected-member, and selected-department eligibility.
- Anonymous and identifiable voting, one vote per event, participation receipts, turnout monitoring, server-calculated results, and result publication.
- Organization audit logs and a separate platform administration area.

## Security model

- Firebase Authentication provides the user identity. Roles are stored per organization, not globally.
- Every organization-scoped backend request checks the authenticated user, active membership, role, and resource ownership.
- Firestore rules deny client writes to votes, participation records, invitation records, results, memberships, and audit logs. Trusted Cloud Functions perform those writes.
- Anonymous ballots omit voter identity and selection data is kept out of participation and receipt records.
- Vote eligibility, duplicate checks, event status, and voting-window checks are enforced by the backend using server time.
- Platform administration uses a trusted `platformAdmin` authentication claim; the client cannot set it.

## Project layout

- `lib/` — Flutter application, organized by feature.
- `functions/src/` — TypeScript Cloud Functions.
- `firestore.rules` and `firestore.indexes.json` — Firestore access policy and indexes.
- `storage.rules` — Cloud Storage access policy.
- `test/` — Flutter unit and widget tests.

## Configure Firebase

1. Install Flutter and Node.js 22, then run `flutter pub get` and `npm --prefix functions install`.
2. Configure Firebase Authentication, Firestore, Cloud Storage, and Cloud Functions in the Firebase project.
3. Set the project alias in `.firebaserc` and configure the Flutter platform files with FlutterFire.
4. Configure the required Cloud Functions secrets in Secret Manager. Invitation email delivery also requires a configured mail delivery provider if email sending is enabled.
5. Review the target Firebase project and deploy the backend resources:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```

Do not grant platform-administrator claims through the client. Assign them through a trusted, reviewed administrative process.

## Build the app

Use Flutter's standard build commands for the intended platform, for example:

```sh
flutter build web
flutter build apk
flutter build ios
```

## Important operational notes

- Organization and platform administration are separate permission systems.
- Organization invitations appear in the recipient's in-app Notifications after they sign in with the invited, verified email address. The recipient can accept or decline; invitations expire after the configured period.
- A Firebase project owner can access backend data outside application-level controls. SecureVote is not a nationally certified election system and does not provide formal cryptographic end-to-end verifiability.
- Performance targets in the SRS assume approximately 100–1,000 eligible voters per event. Larger elections need separate capacity and aggregation planning.

<<<<<<< HEAD
# Secure-E-Voting
SecureVote is a multi-tenant electronic voting and polling platform that allows independent organizations to create and manage secure voting events for their members. The system is designed first as a Final Year Project and as a foundation for a future publicly deployed commercial platform.
=======
# Secure E-Voting System

A Flutter + Firebase e-voting application for academic and club elections (~100–1,000 voters). Built with vote integrity, authentication, one-vote-per-voter enforcement, and ballot anonymity.

## Architecture

```
Flutter App (Riverpod + go_router)
    ├── Firebase Auth        (email/password)
    ├── Cloud Firestore      (elections, candidates, users)
    ├── Cloud Functions      (castVote, getElectionResults, closeElection)
    └── Firebase Storage     (candidate photos)
```

### Security Model


| Threat              | Mitigation                                                       |
| ------------------- | ---------------------------------------------------------------- |
| Unauthorized voting | Firebase Auth required                                           |
| Double voting       | Atomic transaction in `castVote` Cloud Function                  |
| Vote tampering      | Clients cannot write to `votes` collection                       |
| Vote coercion       | Votes stored without `voterId`; participation tracked separately |
| Fake results        | Results aggregated server-side via Cloud Function                |




## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.5+)
- [Node.js 20](https://nodejs.org/)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A Firebase project (or use emulators locally)



## Setup



### 1. Clone and install dependencies

```bash
cd "Secure E Voting System/secure_e_voting"
flutter pub get
cd functions && npm install && cd ..
```



### 2. Configure Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Link to your Firebase project
flutterfire configure
```

Update `.firebaserc` with your project ID if needed.

### 3. Enable Firebase services

In the [Firebase Console](https://console.firebase.google.com/):

- **Authentication** → Email/Password
- **Firestore Database** → Create database
- **Storage** → Enable
- **Functions** → Enable (Blaze plan required for deploy)



### 4. Deploy backend

```bash
firebase deploy --only firestore:rules,storage,functions
```



### 5. Bootstrap first admin

1. Register a user in the app
2. Call the `setAdminRole` Cloud Function with that user's UID:

```bash
# Via Firebase Functions shell or a one-time script
firebase functions:shell
> setAdminRole({ uid: "YOUR_USER_UID" })
```

1. Sign out and sign back in to refresh custom claims



## Local Development (Emulators)

```bash
# Terminal 1: Start Firebase emulators
firebase emulators:start

# Terminal 2: Point the app at emulators (off by default)
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Emulator UI: [http://localhost:4000](http://localhost:4000)

## Project Structure

```
lib/
├── core/           # Theme, router, constants, widgets
├── features/
│   ├── auth/       # Login, register
│   ├── elections/  # Election list, detail
│   ├── voting/     # Vote confirmation
│   ├── admin/      # Election CRUD, candidates, monitor
│   └── results/    # Results charts
├── services/       # Firebase, auth, functions
functions/
├── src/
│   ├── voting/     # castVote, getElectionResults
│   └── admin/      # closeElection, setAdminRole
```



## User Flows



### Voter

1. Register / Sign in
2. View active elections
3. Select candidate → Confirm vote
4. View results after election closes



### Admin

1. Create election (draft → active)
2. Add candidates with photos
3. Monitor turnout (count only, not individual votes)
4. Close election → View results



## Running Tests

```bash
# Flutter unit tests
flutter test

# Cloud Functions tests
cd functions && npm test
```



## Firestore Collections


| Collection                  | Purpose                                |
| --------------------------- | -------------------------------------- |
| `users`                     | User profiles and roles                |
| `elections`                 | Election metadata                      |
| `elections/{id}/candidates` | Candidate info                         |
| `voter_participation`       | One doc per voter per election (dedup) |
| `votes`                     | Anonymous ballots (no voterId)         |
| `audit_logs`                | Admin action trail                     |




## License

MIT — For educational and portfolio use.
>>>>>>> f8e9fbd (Initial commit)

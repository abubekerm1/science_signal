# Science Signal — ICA 16 Class B

Abubeker Mohammed
CSC 4360 — Mobile App Development

Science Signal loads five medium Science & Nature True/False questions
from OpenTDB. After the review, the app saves the score in Firestore
and checks the saved document with a server-only read.

## Android setup

1. Set up Flutter, the Android SDK, and an Android device or emulator.
2. Use the separate Class B Firebase project. For a new setup, enable
   Email/Password sign-in, create two test users, and create the default
   Firestore Standard database in production mode.
3. Publish the included `firestore.rules` in the Class B project's
   Firestore Rules tab.
4. If connecting to a different Firebase project, run `firebase login`
   and `flutterfire configure --platforms=android` from the project root.
5. Run `flutter pub get`, then `flutter run -d <android-device-id>`.
   Use `flutter devices` to find the Android device ID.

## Verify a saved round

1. Sign in as the authorized test user. Any test account access required
   by the grader is shared through an approved private channel.
2. Start a quiz, finish all five questions, and tap **Submit score**.
3. Wait for **Cloud verified** and compare the score and timestamp with
   the matching Firestore document under `users/{uid}/attempts/{roundId}`.
4. Close and relaunch the app while online. Use the same test account.
   Open **Find saved round**, enter the original full round ID, and tap
   **Read from server**. Compare the score and timestamp with step 3.

## Debug test flags

Run one flag at a time with
`flutter run -d <android-device-id> --dart-define=FLAG=true`.

| Flag | Test |
| --- | --- |
| `SCIENCE_SIGNAL_T03` | Inject three invalid trivia responses, then retry the live API. |
| `SCIENCE_SIGNAL_T09` | Deny the first verification read after a real write. Retry the same round. |
| `SCIENCE_SIGNAL_T10` | As User B, use Find saved round to test ownership rules against User A's path. |
| `SCIENCE_SIGNAL_T11` | As User A, use Find saved round to test invalid creates and a denied update. |
| `SCIENCE_SIGNAL_T12` | Inject unavailable and quota errors, then retry the same round. |

## Release APK

Run `flutter build apk --release` without debug flags. The output is
`build/app/outputs/flutter-apk/app-release.apk`. The submission copy is
named `ICA16_B_AbubekerMohammed.apk`.

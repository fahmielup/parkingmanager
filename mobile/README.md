# Parking Shuttle Mobile App

Cross-platform Flutter application for the Off-Site Parking Shuttle Transportation system servicing the CIQ (Customs, Immigration, and Quarantine) route.

## Project Structure

```
mobile/
├── android/            # Android manifest with location, audio, and notification permissions
├── ios/                # iOS Info.plist with location, audio, and background modes
├── lib/
│   ├── constants/      # network_constants, hub_locations, colors, quick replies
│   ├── models/         # VehicleModel, AttendanceModel, ShuttleRequest, ChatMessage
│   ├── services/       # Firestore, Location, Audio, Notification managers
│   ├── screens/
│   │   ├── admin/      # Admin dashboard, attendance, map monitor, chat channels
│   │   ├── driver/     # Driver shift login, jobs, chat
│   │   ├── customer/   # Request form, waiting screen
│   │   └── chat/       # Shared chat room with PTT
│   ├── app.dart        # Root role switcher and Firebase init
│   └── main.dart       # Entry point
├── pubspec.yaml
├── seed_firestore.py   # Firestore mock-data seeding script
└── README.md
```

## Setup

1. Install Flutter (>=3.10.0) and run:
   ```bash
   cd mobile
   flutter pub get
   ```

2. Configure Firebase:
   - Option A: Use the FlutterFire CLI:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
   - Option B: Manually download `google-services.json` and place it in `android/app/`, and `GoogleService-Info.plist` in `ios/Runner/`.

3. Replace `YOUR_GOOGLE_MAPS_API_KEY` in `android/app/src/main/AndroidManifest.xml` with your Google Maps API key.

4. Connect to the local PC backend:
   - The Android Emulator uses `10.0.2.2:5000` (see `lib/constants/network_constants.dart`).
   - Ensure the PC web backend is running at `http://localhost:5000`.
   - If the backend rejects emulator requests, ensure it accepts the `10.0.2.2` origin or disable CORS for development.

## Firestore Emulator (optional)

To run against the Firestore emulator instead of production:

```bash
firebase emulators:start --only firestore
```

Then start the app with:

```bash
cd mobile
flutter run --dart-define=FIRESTORE_EMULATOR=true
```

You can connect to the emulator in code by checking `bool.fromEnvironment('FIRESTORE_EMULATOR')` and calling `FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080)`.

## Seeding Firestore

```bash
cd mobile
pip install firebase-admin
python seed_firestore.py
```

Place your Firebase service account key at `mobile/firebase-service-account.json` or set `GOOGLE_APPLICATION_CREDENTIALS`.

## Running the App

```bash
cd mobile
flutter run
```

Use the role dropdown in the root AppBar to switch between Admin, Driver, and Customer during development.

## Features

- **Admin**: real-time driver attendance, live shuttle map with customer proximity alerts, 3-way chat channels.
- **Driver**: pre-shift clock-in with dynamic vehicle selection, high-visibility job cards, quick replies, and PTT walkie-talkie.
- **Customer**: plan selector, shuttle request form, privacy-safe background GPS sharing, and text-based waiting status (no map).

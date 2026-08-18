# Blox Notify — Flutter App

Android app that shows the current Blox Fruits stock (from the Blox Notify backend) and receives a push notification with a big-picture fruit image whenever the stock changes.

## Features

- On first launch: notification permission prompt + FCM topic subscription (`stock_updates`)
- Current stock screen: 2-column grid of fruit cards (image + name), pull-to-refresh, sensible loading/empty/error states
- Foreground and background notifications rendered with `flutter_local_notifications` using `BigPictureStyle` so the new fruit's image appears in the notification itself

## Requirements

- Flutter 3.44+ (Dart 3.12)
- The backend running somewhere reachable (see `../backend/README.md`)
- A Firebase project with Cloud Messaging enabled (only for real push delivery)

## Manual setup (one-time)

1. Create a Firebase project and register an Android app with package name `com.bloxnotify.blox_notify` (Project Settings → Your apps → Add app → Android).
2. Download `google-services.json` and place it at `android/app/google-services.json`.
3. The Gradle build only applies the Google Services plugin when that file exists, so the project builds without it too (push just won't work).

## Point the app at the backend

The base URL lives in `lib/config.dart` and defaults to `http://10.0.2.2:3000` (the host machine as seen from the Android emulator). For a physical device, pass your machine's LAN IP at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000
```

Same flag when building a release APK. Note the app uses cleartext HTTP for the API (`android:usesCleartextTraffic` is enabled) — switch the backend to HTTPS and remove that flag if you deploy publicly.

## Run

```bash
flutter pub get
flutter run                     # with an emulator/device connected
```

## Tests

```bash
flutter analyze
flutter test                    # widget tests (no device needed)
flutter test integration_test -d <device-id>
```

- `test/stock_screen_test.dart` — stock grid renders fruit cards, plus empty/error/retry states (mocked HTTP client)
- `test/onboarding_screen_test.dart` — permission + topic subscription flow with a fake push service
- `integration_test/app_test.dart` — on a real device/emulator: launch → tap enable → permission requested → subscribes to `stock_updates` → stock screen shown (uses the same fake push service, no Firebase credentials required)

## Release build

```bash
keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias blox-notify
```

Wire the keystore into `android/app/build.gradle.kts` (replace the debug-signing block in `buildTypes.release`), then:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.example.com
```

The APK is sideloaded — enable "install unknown apps" on the test device.

# Blox Notify — Development Plan

## 1. Scope

**Functional**
- Poll the Blox Fruits Fandom wiki stock page on an interval.
- Detect when the current stock changes (new fruit list).
- Push a notification to all installed apps when stock changes, including fruit image(s).
- App shows current stock on open (not just via notification).

**Non-functional**
- No user accounts / login — this is a broadcast-only utility.
- No per-device data stored server-side (avoids GDPR/PII concerns and a device-token DB).
- Backend must run continuously (long-lived polling process, not a request-driven serverless function).
- Known limitation: the wiki is community-edited, not a live game feed — see note below. Notification speed is capped by how fast a wiki editor updates the page, typically within a few minutes of a real restock, but not guaranteed.

**Out of scope for v1**: Mirage/Advanced dealer stock (harder to source reliably), iOS, user preferences/filtering by fruit.

---

## 2. Tech Stack Decision

Evaluated on fit for *this* project only:

| Layer | Choice | Why |
|---|---|---|
| Backend | **Node.js + Express** | First-class Firebase Admin SDK support, `cheerio`/`axios` make wikitext scraping and HTTP polling trivial, single language for the whole backend, huge testing ecosystem (Jest/Supertest). Python+Flask+APScheduler is an equally valid alternative — Node wins narrowly on push-notification tooling maturity. |
| Scheduler | `node-cron` | In-process cron, no external infra needed for a single-instance service. |
| State store | Flat JSON file (`lowdb` or hand-rolled) | The only state is "last known stock" — a full DB (SQL/Mongo) is overkill for one record. |
| Push delivery | **Firebase Cloud Messaging (FCM), topic-based** | Free, reliable, no need to track individual device tokens — app subscribes to one topic (`stock_updates`), backend publishes to that topic. |
| Mobile app | **Flutter** | Single codebase → one APK, mature `firebase_messaging` + `flutter_local_notifications` (supports big-picture-style notifications with the fruit image), fast to build a 2-screen app. |
| Testing | Jest + Supertest (backend), `flutter_test` + `integration_test` (app) | Standard, well-documented, works offline in CI. |
| Hosting | Any always-on Node host (Railway, Render, Fly.io, or your own VPS) | Needs to run 24/7 for the cron loop — serverless functions (Vercel/Netlify) don't fit this shape. |

---

## 3. Architecture & Data Flow

```
             every 90s
[node-cron] ─────────────► [fetch wiki stock page via MediaWiki API]
                                        │
                                        ▼
                          [parse current stock section]
                                        │
                                        ▼
                     [compare to last-known-stock.json]
                                        │
                              changed? ─┴─ no  → do nothing
                                 │ yes
                                 ▼
              [update last-known-stock.json]
                                 │
                                 ▼
        [Firebase Admin SDK → send to topic "stock_updates"]
                                 │
                                 ▼
                    [Flutter app: background/foreground
                     handler shows notification w/ fruit image]

Separately:
[Flutter app on launch] ──GET /stock──► [Express: returns last-known-stock.json]
```

---

## 4. Project Structure

```
blox-notify/
├── backend/
│   ├── src/
│   │   ├── index.js              # Express app entry
│   │   ├── poller.js             # cron job + orchestration
│   │   ├── wikiClient.js         # fetches raw wikitext from MediaWiki API
│   │   ├── stockParser.js        # wikitext → { fruits: [...] } (pure function)
│   │   ├── stockStore.js         # read/write last-known-stock.json
│   │   ├── notifier.js           # builds FCM payload, sends via firebase-admin
│   │   └── routes/stock.js       # GET /stock
│   ├── test/
│   │   ├── stockParser.test.js       # unit
│   │   ├── stockStore.test.js        # unit
│   │   ├── notifier.test.js          # unit (mocked firebase-admin)
│   │   └── stock.route.test.js       # integration (Supertest)
│   ├── package.json
│   └── .env.example
└── app/                            # Flutter project
    ├── lib/
    │   ├── main.dart
    │   ├── services/fcm_service.dart
    │   ├── services/stock_api.dart
    │   ├── screens/stock_screen.dart
    │   └── models/fruit.dart
    ├── test/                       # widget/unit tests
    ├── integration_test/           # end-to-end app test
    └── pubspec.yaml
```

---

## 5. SDLC Phases

1. **Requirements & design** — this document. Lock scope before coding.
2. **Backend build** — implement `wikiClient` → `stockParser` → `stockStore` → `notifier` → `poller`, in that order, each with unit tests before wiring together.
3. **Backend integration testing** — Supertest against the `/stock` route; mock the wiki HTTP call and `firebase-admin` so tests run without network/credentials.
4. **Manual backend verification** — run locally against the real wiki once, confirm parsing is correct against the actual current stock.
5. **Frontend build** — scaffold Flutter app, FCM integration, stock screen.
6. **Frontend testing** — widget tests for the stock screen, integration test for notification-permission + topic subscription flow.
7. **Manual setup** — Firebase project, `google-services.json`, signing keystore (see §7).
8. **End-to-end test** — deploy backend, install debug APK on a real device, wait for/force a stock change, confirm notification arrives with image.
9. **Release build** — signed release APK.
10. **Deploy & monitor** — backend hosted continuously; check logs after a few real restock cycles.

---

## 6. Testing Strategy Summary

**Backend unit tests** (no network, no Firebase):
- `stockParser`: feed it saved wikitext fixtures (a "before" and "after" sample) → assert correct fruit list extraction.
- `stockStore`: read/write round-trip on a temp file.
- `notifier`: mock `firebase-admin`, assert `send()` is called with the expected topic and payload shape when given a stock diff.

**Backend integration test**:
- Supertest hits `GET /stock`, asserts it returns whatever `stockStore` currently holds (seed the temp file first).

**Frontend widget tests**:
- Stock screen renders a list of fruit cards given mock API data.
- Empty/error states render sensibly.

**Frontend integration test**:
- App launch → permission prompt → topic subscription call fires (mock the Firebase plugin channel).

**Manual-only** (can't be automated without a real device + real Firebase project):
- Actual push delivery and the big-picture notification image rendering.
- Real wiki parsing against live data (do this once before trusting the automated tests' fixtures).

---

## 7. Manual Setup Steps (things you do outside the code)

1. **Firebase project**: create one in the Firebase console, enable Cloud Messaging.
2. **Android app registration**: add an Android app in Firebase (package name must match your Flutter app's `applicationId`), download `google-services.json`, place it in `app/android/app/`.
3. **Service account key**: generate a Firebase service-account JSON (Project Settings → Service Accounts) for the backend to authenticate with `firebase-admin`. Keep it out of git — load via env var.
4. **Signing keystore**: `keytool -genkey -v -keystore release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias blox-notify` — needed to produce an installable release APK.
5. **Backend hosting**: deploy the `backend/` folder to an always-on host, set env vars (`FIREBASE_SERVICE_ACCOUNT`, `PORT`, `POLL_INTERVAL_MS`), note the public URL.
6. **Point the app at the backend**: set that URL as the base API URL in `app/lib/services/stock_api.dart` (or an env config) before building the release APK.
7. **Sideloading**: since this won't start on the Play Store, you'll install the APK directly — enable "install unknown apps" on the test device.

---

## 8. One-Shot Development Prompt

Paste this into Claude Code (or a similar coding agent) once you're ready to generate the project:

```
Build a project called "blox-notify" with two folders: backend/ and app/.

BACKEND (Node.js + Express):
- Poll https://blox-fruits.fandom.com/api.php?action=parse&page=Blox_Fruits_%22Stock%22&prop=wikitext&format=json every 90 seconds using axios, on a node-cron schedule.
- Parse the returned wikitext to extract the current stock's list of fruit names (ignore Last Stock / Before Last Stock sections). Put this in a pure function stockParser.js that takes raw wikitext and returns { fruits: string[] } so it's unit-testable with fixture text, no network needed.
- Persist the last-known stock to a local JSON file via a stockStore.js module (read/write helpers, no external DB).
- On each poll, compare the newly parsed stock to the stored one. If different: update the store, then call a notifier.js module that uses the firebase-admin SDK to send a message to FCM topic "stock_updates" containing the new fruit names and their image URLs (image URL pattern: https://static.wikia.nocookie.net/blox-fruits/images/.../<FruitName>.png — look up the real filenames from the wiki's fruit infobox images per fruit if a direct mapping isn't available; fall back to no image rather than a wrong one).
- Expose GET /stock returning the current stored stock as JSON.
- Load the Firebase service account credentials from an environment variable (FIREBASE_SERVICE_ACCOUNT, a JSON string), not a committed file.
- Write Jest unit tests for stockParser and stockStore using fixture wikitext files, and a mocked-firebase-admin test for notifier. Write a Supertest integration test for GET /stock.
- Include a .env.example listing required env vars and a README with local run instructions.

APP (Flutter):
- Two screens: a splash/home screen showing the current stock (fetched from GET /stock on the backend, pull-to-refresh) as a grid of fruit name + image, and permission handling for notifications on first launch.
- Use firebase_messaging to subscribe the device to FCM topic "stock_updates" on launch, and flutter_local_notifications to display incoming background/foreground messages using BigPictureStyle so the fruit image shows in the notification itself.
- Keep state management simple — StatefulWidget/setState is fine, no need for a state management library given the app's small scope.
- Read the backend base URL from a single config constant so it's easy to change before building a release APK.
- Write widget tests for the stock screen (mock API response → renders fruit cards; empty/error states), and one integration_test that verifies the app requests notification permission and attempts topic subscription on launch.

Do not implement the Mirage/Advanced dealer stock, user accounts, or iOS support in this pass. Ask me before adding any dependency not listed above.
```

---

## 9. Known Risk / Caveat

The Fandom stock page is manually maintained by wiki editors, not an automated game feed — there's no official API. This plan matches how existing community stock bots work (poll + diff the wiki), but notification timing is only as fast as the next wiki edit, and occasional wrong or missed edits are possible. Worth validating manually against real stock rotations before relying on it.
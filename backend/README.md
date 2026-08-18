# Blox Notify — Backend

Polling service that watches the [Blox Fruits wiki stock page](https://blox-fruits.fandom.com/wiki/Blox_Fruits_%22Stock%22) every 90 seconds, detects stock rotations, persists the last-known stock, and pushes a Firebase Cloud Messaging (FCM) notification to the `stock_updates` topic whenever the stock changes.

## How it works

```
[node-cron every 90s] → [MediaWiki API: fetch stock page wikitext]
                              ↓
                     [stockParser: extract "Current" fruits]
                              ↓
                [compare to data/last-known-stock.json]
                              ↓ changed?
                          (no → do nothing)
                              ↓ yes
             [update state file] → [notifier: FCM topic push + fruit images]
```

Separately, `GET /stock` serves the last-known stock (with resolved fruit image URLs) for the Flutter app.

## Requirements

- Node.js >= 18
- A Firebase project with Cloud Messaging enabled and a service-account JSON key (only needed for push notifications)

## Setup

```bash
npm install
cp .env.example .env
```

Edit `.env`:

- `FIREBASE_SERVICE_ACCOUNT` — the full service-account JSON, as a single-line string. Required for notifications. Without it the backend still polls and serves `/stock` but skips sending.
- `PORT` — default `3000`.
- `POLL_INTERVAL_MS` — poll interval in milliseconds, default `90000`.

## Run

```bash
npm start          # production
npm run dev        # auto-restart on changes (Node >= 18 --watch)
```

## API

### `GET /stock`

Returns the last-known stock:

```json
{
  "fruits": [
    { "name": "Spring", "imageUrl": "https://static.wikia.nocookie.net/..." },
    { "name": "Flame",  "imageUrl": "https://static.wikia.nocookie.net/..." }
  ],
  "updatedAt": "2026-08-18T14:43:01.005Z"
}
```

An empty `fruits` array means no stock has been recorded yet.

## Tests

```bash
npm test
```

- `stockParser` — unit tests against wikitext fixtures in `test/fixtures/`
- `stockStore` — read/write round-trip on temp files
- `notifier` — payload shape + send behaviour with a mocked `firebase-admin`
- `poller` — full poll cycle orchestration (mock wiki + notifier)
- `stock.route` — Supertest integration test for `GET /stock`

All tests run offline, no network or Firebase credentials needed.

## Verify against the live wiki

```bash
npm run verify:wiki
```

Fetches the real page, prints the parsed stock and resolves fruit image URLs — run this once before trusting a fresh wiki page format.

## Fruit images

Image filenames follow the wiki convention `<FruitName>_Fruit.png` and are mapped in `src/fruitImages.js`. Full URLs can't be derived statically (the static CDN path contains a per-file hash), so the backend resolves them once per fruit through the MediaWiki `imageinfo` API and caches the result in memory. Unknown fruits get no image rather than a wrong one — add new fruits to `FRUIT_IMAGE_FILES` as needed.

## Deployment notes

### Docker

```bash
docker build -t blox-notify-backend .
docker run -p 3000:3000 --env-file .env blox-notify-backend
```

### CI/CD (GitHub Actions + GHCR + Render)

- `.github/workflows/ci.yml` — on every push/PR to `main`: backend Jest tests, Flutter `analyze` + `test`, and (when the `GOOGLE_SERVICES_JSON` base64 secret is set) a debug APK artifact for sideloading.
- `.github/workflows/deploy.yml` — on push to `main` touching `backend/`: builds the backend image, pushes it to `ghcr.io/<your-username>/blox-notify-backend`, then triggers Render via the deploy hook.
- `render.yaml` — Render Blueprint that deploys the backend from the GHCR image with the right env vars.

Setup (one-time):

1. Push this repo to GitHub (`git init && git add . && git commit && git remote add origin ... && git push`).
2. **GitHub secrets** — `RENDER_DEPLOY_HOOK_URL` (create it in Render: Dashboard → your service → Deploy Hook) and optionally `GOOGLE_SERVICES_JSON` (`base64 -w0 app/android/app/google-services.json` on Linux/Mac, `certutil -encode` or PowerShell on Windows) to get debug APK artifacts.
3. **Render** — connect the repo (Blueprints), connect GitHub Container Registry (Dashboard → Connect a Registry) so the private image can be pulled, and edit `render.yaml`: replace `YOUR_GITHUB_USERNAME` with your GitHub username. Set the `FIREBASE_SERVICE_ACCOUNT` env var in the Render dashboard (service account JSON as one line), or mount it as a secret file and set `FIREBASE_SERVICE_ACCOUNT_FILE` instead.

Runs as a long-lived process — any always-on Node host (Railway, Render, Fly.io, a VPS) works. Serverless functions (Vercel/Netlify) do not fit this shape.

Caveat: the wiki is community-edited, not a live game feed. Notification speed is capped by how fast an editor updates the page.

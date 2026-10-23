# Unbrick

Unbrick is a Korean study app (KIIP 중급 1). On iPhone it is a SwiftUI app: lessons, quizzes, review, a calendar, and an AI tutor, with a lock screen that asks you to practice before an unlock window. Open `Unbrick/Unbrick.xcodeproj`.

The Anthropic key is not in the app. Grading and the tutor call a small Cloudflare Worker in `backend/`, which holds the key and stops at a US$0.55 daily cap and a US$100 total cap (about six months). The worker uses Claude Haiku. Until `UNBRICK_API_BASE` and `UNBRICK_APP_TOKEN` are set in `Unbrick/Config/Info.plist`, the iPhone app uses on-device Apple Intelligence when that is available, and does not call Claude. When the cap is hit, the phone shows that the tutor is resting and falls back to on-device checking when Apple Intelligence is on.

Android cannot run SwiftUI. `android/` is a Jetpack Compose scaffold that reuses the lesson JSON and the same worker. App blocking is a different API on each platform and is not implemented on Android. See `android/README.md`.

What you still have to do by hand (accounts, signing, the API key, TestFlight, store listings) is `LAUNCH.md`.

| Path | What it is |
| --- | --- |
| `Unbrick/Unbrick` | iOS app sources, asset catalog, `PrivacyInfo.xcprivacy` |
| `Unbrick/Unbrick/Resources/Content.json` | Lessons bundled in the app |
| `Unbrick/content` | Per-unit source JSON |
| `Unbrick/Config/Info.plist` | Usage strings, bundle URL scheme, server URL and app token |
| `Unbrick/web/privacy.html` | Same privacy policy the worker serves at `/privacy` |
| `store/APP_STORE_LISTING.md` | Paste-ready App Store Connect text |
| `Unbrick/web/unbrick.html` | Browser prototype. It is not the store binary. |
| `backend` | Claude proxy. Env vars are in `backend/README.md`. |
| `android` | Compose scaffold |

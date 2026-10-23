# Launch checklist

Steps only you can do. The repo does not contain an Anthropic key, a signing certificate, or store accounts.

## 1. Anthropic and the server

The worker is capped so six months of use stays inside US$100 of Anthropic credits. It uses Claude Haiku 5.5, reserves the worst-case cost of each call before contacting Anthropic, and records the real token usage after. Defaults (all overridable in `wrangler.toml`):

| Setting | Default |
| --- | --- |
| Model | `claude-haiku-5-5` |
| `MAX_TOKENS` | `1024` (hard ceiling `2048`) |
| Effort | forced to `low` |
| History sent | last 6 messages, 800 characters each; lesson prompt trimmed to 4000 plus the worker's policy line |
| Daily global cap | US$0.55 (`DAILY_BUDGET_USD`) |
| Total cap | US$100 (`TOTAL_BUDGET_USD`) |
| Per device | 30 messages per UTC day (`DEVICE_DAILY_LIMIT`), on top of 12 requests per IP per minute |
| Input price | US$0.10 / million tokens (`PRICE_INPUT_PER_MTOK`) — Haiku 5.5, prompts ≤100k, as of 2026-10-07 |
| Output price | US$0.50 / million (`PRICE_OUTPUT_PER_MTOK`) |
| Cache write | US$0.20 / million (`PRICE_CACHE_WRITE_PER_MTOK`) — the 1-hour Haiku rate, used so a later cache cannot be undercounted |
| Cache read | US$0.01 / million (`PRICE_CACHE_READ_PER_MTOK`) |
| Reserve | 2 tokens per character of the outgoing JSON (`RESERVE_TOKENS_PER_CHAR`), priced at the higher of the input and cache-write rates, plus `MAX_TOKENS` of output |

US$0.55 × about 182 days is US$100, so the daily pace and the total cap together stop a busy stretch from passing the six-month budget. Only two people are expected to use it; 30 messages a day per device is the extra limit on top of the IP cap. When either money cap or the per-device cap is hit, the worker responds with HTTP 429 and `error.code` `resting`: "AI tutor is resting, try again tomorrow". The iPhone app shows that and, when Apple Intelligence is on, grades on the device instead. Android shows the same sentence. There is no on-device model there.

Spend is stored in one Durable Object (`SPEND` / `SpendGuard`), not KV. A hard cap has to be atomic, and KV is eventually consistent, so two requests at once could both pass. The first `wrangler deploy` applies the migration that creates the object. If that binding is missing, the worker refuses to call Anthropic.

- [ ] Create an Anthropic API key. Do not paste it into the app, Info.plist, or git.
- [ ] In the Anthropic console, set a workspace or key spend limit of US$100. That is the lock Anthropic itself enforces if the worker's price table is ever wrong.
- [ ] Install Node and deploy: `cd backend && npx wrangler login && npx wrangler deploy`. Leave the `SpendGuard` migration in place.
- [ ] Secrets (not in `wrangler.toml`):
  - `npx wrangler secret put ANTHROPIC_API_KEY`
  - `npx wrangler secret put APP_TOKEN` — a long random string. The same value goes in the apps. It is not the Anthropic key. Anyone who unpacks the app can read it.
- [ ] If you change `ANTHROPIC_MODEL`, update every `PRICE_*` var to that model's published price in the same edit. A cheaper number in the config than the real invoice lets the guard sail past US$100. Haiku 4.5 is a different, more expensive model; do not point the name at it without changing prices.
- [ ] Confirm `GET https://<your-worker>/health` returns `"configured": true` and `"spendGuard": true`.
- [ ] Read `backend/README.md` for the full env list.

## 2. Privacy page

- [ ] Edit `Unbrick/web/privacy.html`: replace `[legal name of the developer or company]` and `[support email]`.
- [ ] Host the file at a public HTTPS URL (Cloudflare Pages, GitHub Pages, or any static host). App Store Connect and Play Console both require a privacy policy URL.
- [ ] Put that URL in `UNBRICK_PRIVACY_URL` in `Unbrick/Config/Info.plist`.

## 3. Point the iOS app at the server

- [ ] In `Unbrick/Config/Info.plist`, set `UNBRICK_API_BASE` to the worker origin only, for example `https://unbrick-api.<account>.workers.dev` (no `/v1/task`).
- [ ] Set `UNBRICK_APP_TOKEN` to the same string as `APP_TOKEN`.
- [ ] Leave both empty in any build you don't want calling Claude. Those builds fall back to Apple Intelligence on the device.
- [ ] A Debug build may use `http://localhost` or `http://127.0.0.1` for `wrangler dev`. Release builds accept only `https`.

## 4. Apple Developer and signing

- [ ] Enroll in the Apple Developer Program.
- [ ] Confirm the team id in `Unbrick/Unbrick.xcodeproj/project.pbxproj` (`DEVELOPMENT_TEAM`, currently `4U2PAVU9J3`) is your team. Change it if it is not.
- [ ] Confirm the bundle id `com.imexglobalintl.unbrick`. It cannot be changed after the first App Store upload.
- [ ] In Xcode, open `Unbrick/Unbrick.xcodeproj`, select the shared Unbrick scheme, and set signing to your team (Automatic is already selected).
- [ ] Version is `1.0` (`MARKETING_VERSION`) and build `1` (`CURRENT_PROJECT_VERSION`). Raise the build number for every upload after the first. Never reuse a build number.

## 5. Family Controls (real app blocking)

The app does not block other apps by itself. Home-screen tiles are practice shortcuts. Real blocking today is the Screen Time passcode guide, which the learner sets up in Settings. That is allowed to ship, but it is not the Family Controls API.

- [ ] If you want Unbrick itself to shield apps, request the Family Controls (Distribution) entitlement from Apple for `com.imexglobalintl.unbrick`, for an individual (not a child) authorization.
- [ ] Do not add `Unbrick/Config/FamilyControls.entitlements.example` to the target before Apple approves it. Signing fails until the profile contains the capability. The file explains the two lines to add after approval.
- [ ] After approval, implement `AuthorizationCenter` (`.individual`), `FamilyActivityPicker`, and `ManagedSettings` shields, plus a Device Activity Monitor extension so the shield comes back when the phone is locked and the app is not running. `NSFamilyControlsUsageDescription` is already in Info.plist.
- [ ] Do not instruct people to disable Apple Account recovery for the Screen Time passcode. The in-app steps no longer say that. A lost passcode with recovery turned off can lock Screen Time with no way back, and review treats "disable recovery" as circumventing device security.

## 6. Privacy labels and permissions

Already in the project, for you to mirror in App Store Connect:

- [ ] Microphone: `NSMicrophoneUsageDescription`
- [ ] Speech recognition: `NSSpeechRecognitionUsageDescription`
- [ ] Notifications: there is no plist string. The system prompt is the local "unlock ended" alert. Answer the notifications question in App Store Connect as local notifications, not push.
- [ ] Family Controls string is present for the day the entitlement is on. The binary does not call that API yet.
- [ ] `PrivacyInfo.xcprivacy` declares no tracking, audio data, and other user content (the answer text), both for app functionality and not linked to identity. Match the nutrition labels to that, and to `Unbrick/web/privacy.html`.
- [ ] `ITSAppUsesNonExemptEncryption` is false (HTTPS only). You can answer the export question as no non-exempt encryption.
- [ ] The 1024×1024 app icon has no alpha channel (`Unbrick/Unbrick/Assets.xcassets/AppIcon.appiconset/icon.png`).

## 7. TestFlight and the App Store

- [ ] Archive the Release scheme in Xcode and upload with the Organizer or `xcodebuild -exportArchive`.
- [ ] On a phone: speak an answer, finish a card set, open the tutor, and confirm Claude replies only after the worker is configured. Confirm Profile no longer asks for an API key.
- [ ] Create the App Store Connect record, screenshots, description, age rating, support URL, and the privacy policy URL.
- [ ] Submit for review. Mention that blocking is Screen Time the user configures, and that answer text is sent to your server and then Anthropic when Claude is enabled.

## 8. Google Play

Do not start a Flutter or React Native rewrite. The recommendation is in `android/README.md`: keep iOS on SwiftUI, and grow the Compose scaffold.

- [ ] Create a Play Console developer account.
- [ ] Open `android/` in Android Studio. Copy `local.properties.example`'s two lines into `local.properties` with the same base URL and app token.
- [ ] Generate a Play upload key and turn Play App Signing on. Nothing in the repo is a keystore.
- [ ] The scaffold is not a store-ready port. Before you list it: quizzes, review, a real blocking design (usage access / accessibility / device policy — not a port of the iOS passcode), a launcher icon from the iOS 1024 asset, and the Data safety form (microphone, speech text sent to your server, no ads, no account).
- [ ] Use the same privacy policy URL.

## 9. If a key ever leaked

- [ ] No Anthropic key was in the imported source. Older test builds on a phone may still have had a learner-typed key in the Keychain under `com.imexglobalintl.unbrick.anthropic`. The current app deletes that item on launch. Revoke any key you pasted into a build or a chat, and use only the worker secret from here on.

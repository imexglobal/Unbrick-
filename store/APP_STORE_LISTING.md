# App Store listing — Unbrick: Learn Korean

Paste these into the existing App Store Connect record. The home-screen name stays **Unbrick**. The store name stays **Unbrick: Learn Korean**. Bundle id `com.imexglobalintl.unbrick`. This submission is version **1.0**, build **2**. Team **6388ACWLTQ**. Publisher **IMEX Global**.

Deploy the worker before you archive, then confirm both URLs load. Privacy Policy URL and Support URL:

- https://unbrick-api.unbrick.workers.dev/privacy
- https://unbrick-api.unbrick.workers.dev/support

Before you archive build 2, put the worker’s `APP_TOKEN` into `UNBRICK_APP_TOKEN` in `Unbrick/Config/Info.plist` on the Mac you archive from. The copy in git is empty. Without that token the server tutor stays off. Do not put the Anthropic key in the app. The review notes below assume the token is in the binary you upload.

Copyright: `2026 IMEX Global`

Primary category: **Education**. Secondary: **Reference**.

## Subtitle

21 characters (limit 30).

```
Speak Korean out loud
```

## Promotional text

131 characters (limit 170). Can be changed without a new binary.

```
Speak Korean answers out loud, review the KIIP 중급 1 book, and practice with an AI tutor. No account. Progress stays on your iPhone.
```

## Description

```
Unbrick is Korean speaking practice for the KIIP 중급 1 book (level 3). Lessons, vocabulary, grammar, role-play, and a calendar stay on your iPhone. There is no account and nothing to sign in to.

Speak your answers. Unbrick uses the microphone and Apple’s speech recognition to turn Korean into text, then plays the model sentence in a Korean voice. The screen can be English or Russian.

The AI tutor and the card check reply in the language you picked. This build sends the text of your answer and the lesson prompt to Unbrick’s server, which asks Anthropic’s Claude and returns the feedback. The recording stays on the iPhone. If Apple Intelligence is on, the phone can grade on the device instead, including when the shared tutor budget for the day is used up. The app then says the tutor is resting until tomorrow.

Tiles on the Home screen are practice shortcuts inside Unbrick. They do not close Instagram, TikTok, YouTube, or any other app. If you want those limits, the app walks you through setting them yourself in Settings under Screen Time, and it can keep that passcode on this iPhone until you finish a session. This version does not use Family Controls and does not shield other apps by itself.

No ads. No tracking. Delete Unbrick to remove what it stored on the phone. There is no account to delete.
```

## Keywords

92 characters (limit 100). Commas, no spaces. The app name, “learn”, and “Korean” are already in the store name, so they are not repeated here.

```
kiip,hangul,tutor,flashcards,speaking,pronunciation,grammar,vocabulary,screentime,visa,topik
```

## Age rating

Answer every content question **None** / **No**. Expected result: **4+**. Do not put the app in Made for Kids.

| Question | Answer |
| --- | --- |
| Cartoon or fantasy violence | None |
| Realistic violence | None |
| Sexual content or nudity | None |
| Profanity or crude humor | None |
| Horror or fear themes | None |
| Alcohol, tobacco, or drugs | None |
| Mature or suggestive themes | None |
| Gambling | None |
| Contests | None |
| Medical or treatment information | None |
| Unrestricted web access | No |
| User-generated content that other people can see | No. Cards the learner writes stay on the device. |
| Messaging or chat with other users | No. The tutor is a model, not another person. |
| Advertising | No |
| Parental controls | None. Screen Time instructions are for the learner’s own phone, not a child account. |
| Age assurance | None |
| Loot boxes or simulated gambling | None |

## App Privacy (nutrition label)

Data used to track the user: **none**. Tracking is off in `PrivacyInfo.xcprivacy`. There is no advertising identifier and no tracking SDK.

Data linked to the user’s identity: **none**. There is no account, name, or email collected from the learner.

Data not linked to the user’s identity. Purpose for each is **App Functionality** only. Do not check Analytics, Advertising, or Third-Party Advertising.

| Data type | Declare | Why |
| --- | --- | --- |
| Audio Data | Yes | Microphone audio is turned into text. When Korean on-device recognition is available, Unbrick requires it and the audio stays on the phone. When it is not, Apple’s speech service may receive the audio. The audio file is not sent to IMEX Global. |
| Other User Content | Yes | The text of an answer and the lesson prompt are sent to the Unbrick worker and then to Anthropic when the server tutor is on. |
| User ID | Yes | A random install id created by the app (Keychain UUID). It is not the advertising id and not `identifierForVendor`. It is sent so the server can cap how many tutor messages that install can send in a day. |
| Contact Info, Location, Health, Financial Info, Sensitive Info, Contacts, Photos, Search History, Browsing History, Purchases, Product Interaction, Crash Data, Performance Data, Device ID | No | Not collected. Do not check Device ID: the app does not read the advertising identifier or the vendor id. The IP address is used by the worker only as a one-minute rate-limit counter and is not stored as a profile or turned into a location, so it is not a location data type. |

Third parties that receive data: **Anthropic** receives the answer text and lesson prompt. **Apple** may receive speech audio when on-device recognition is unavailable. No ad networks.

This matches `Unbrick/Unbrick/PrivacyInfo.xcprivacy`.

## Export compliance

`ITSAppUsesNonExemptEncryption` is false. The app uses HTTPS only. It does not implement its own encryption.

If App Store Connect or the upload dialog asks what encryption the app implements, answer **None of the algorithms mentioned above** (standard HTTPS through the operating system only). The app is exempt. No French encryption declaration and no CCATS document.

## Review notes

Paste into App Review Information. There is no demo account. Leave the username and password blank.

```
There is no account, no password, and no in-app purchase. Sign-in fields are not used.

How to reach the AI tutor: open the app, tap Continue on the setup screen (language, goal, and how long an unlock timer lasts), then on Home tap AI tutor. You can also open it from a practice tile. Allow the microphone and speech recognition when iOS asks. Type or speak a short Korean answer, for example 안녕하세요. Feedback comes back in English or Russian, depending on the language chosen in setup. Profile shows which checker is active (Claude, or Apple on-device AI).

This binary does not use Family Controls. It does not call AuthorizationCenter, FamilyActivityPicker, or ManagedSettings, and it has no Family Controls entitlement or purpose string. There should be no Family Controls system prompt. Tiles labeled Instagram, TikTok, and the others are practice shortcuts inside Unbrick. Tapping one opens a practice lock in this app. It does not close or shield the other app. Screen Time setup (Profile → Blocking setup, or Home → Turn on real blocking) is a set of instructions for Settings. Please skip it. The passcode Unbrick can generate is stored only in this iPhone’s Keychain.

Privacy policy (also Profile → Privacy policy → Full policy):
https://unbrick-api.unbrick.workers.dev/privacy

Support (also Profile → Privacy policy → Contact support):
https://unbrick-api.unbrick.workers.dev/support

The publisher is IMEX Global, hellopawfend@gmail.com. Deleting the app removes on-device progress. There is no account to delete.
```

## What to Test

Paste into TestFlight’s What to Test for build 2. Keep it short.

```
Build 2. No account. After setup, Home → AI tutor: type or speak 안녕하세요 and confirm a reply, or a clear resting / unavailable message. Profile → Privacy policy opens the summary, the public policy, and support. Practice tiles do not close other apps. Skip Screen Time setup. There is no Family Controls prompt.
```

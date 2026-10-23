# Android

SwiftUI cannot run on Android. The iPhone app should stay native. A cross-platform rewrite (Flutter, React Native, or Kotlin Multiplatform UI) would throw away the working SwiftUI screens and still could not share app blocking: iOS Screen Time / Family Controls and Android's usage-access, accessibility, or device-policy APIs are different products.

This module is a Jetpack Compose scaffold. It reads the same `Unbrick/Unbrick/Resources/Content.json` (copied at build time) and calls the same Cloudflare worker as the iPhone app.

What works in the scaffold:

- List of the 16 KIIP units, with vocabulary and the English or Russian gloss
- A tutor screen that posts `tutor` tasks to `/v1/task`, plus the system speech recognizer and Korean text-to-speech. Each install sends a stable `X-Unbrick-Device` id. At the daily message cap, or when the shared US$0.55 / US$100 budget is used up, the screen shows "AI tutor is resting, try again tomorrow". Android has no on-device model to fall back to.

What is not built, and has to be designed for Android on its own:

- App blocking. There is no Screen Time passcode and no Family Controls. A real block needs a usage-access prompt, an accessibility service or a device-policy controller, and a shield that is hard to dismiss. The Blocking tab only explains that.
- Quizzes, spaced repetition, the calendar, role-play, and on-device grading
- Store listing graphics. The launcher icon is a placeholder; the 1024 iOS icon is `Unbrick/Unbrick/Assets.xcassets/AppIcon.appiconset/icon.png`

Open `android/` in Android Studio. Put the worker URL and app token in `local.properties` (see `local.properties.example`). They are not the Anthropic key.

Versions are pinned to Android Gradle Plugin 8.5.2, Kotlin 2.0.20, and compileSdk 34 so the project opens without a newer SDK. Studio can bump them later.

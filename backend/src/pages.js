/**
 * Public pages served by the worker. No extra host. Keep Unbrick/web/privacy.html
 * and Unbrick/web/support.html in step with this file.
 */

const PUBLISHER = "IMEX Global";
const EMAIL = "hellopawfend@gmail.com";
const UPDATED = "23 October 2026";

function page(title, body) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
  :root { color-scheme: light dark; }
  body { margin: 0 auto; max-width: 42rem; padding: 2rem 1.25rem 4rem; font: 1.05rem/1.55 system-ui, sans-serif; }
  h1 { font-size: 1.8rem; line-height: 1.2; }
  h2 { font-size: 1.15rem; margin-top: 2rem; }
  a { color: inherit; }
</style>
</head>
<body>
${body}
<p><a href="/privacy">Privacy policy</a> · <a href="/support">Support</a></p>
</body>
</html>
`;
}

export const privacyHtml = page(
  "Unbrick privacy policy",
  `<h1>Unbrick privacy policy</h1>
<p>Unbrick (App Store name “Unbrick: Learn Korean”) is a Korean study app from <strong>${PUBLISHER}</strong>, bundle id <code>com.imexglobalintl.unbrick</code>. Contact: <a href="mailto:${EMAIL}">${EMAIL}</a>. Last updated ${UPDATED}.</p>
<p>There is no Unbrick account. The app does not ask for your name, email, phone number, contacts, photos, or location. It does not show ads, and it does not track you across other companies’ apps or websites.</p>

<h2>What stays on this iPhone</h2>
<ul>
  <li>Study progress is a file in the app’s local storage: scores, streak, the unit you are on, the goal and date you set, cards you added, and which practice tiles you marked. It is not uploaded.</li>
  <li>If you create a Screen Time passcode in Unbrick, that code is stored in the iOS Keychain on this iPhone. It is not sent to IMEX Global or Anthropic.</li>
  <li>The app creates a random id for this install and stores it in the Keychain. It is not the advertising identifier and not the device vendor id.</li>
  <li>When you speak an answer, Unbrick writes a short recording in a temporary file so you can play it back. iOS clears temporary files. That audio file is not uploaded to the Unbrick server.</li>
</ul>

<h2>Microphone and speech</h2>
<p>The microphone is used so you can speak Korean answers. Apple’s Speech Recognition turns that audio into text. When this iPhone supports on-device recognition for Korean, Unbrick requires on-device recognition, so the audio stays on the phone. When it does not, Apple’s speech service may receive the audio. Unbrick does not send the audio file to its own server.</p>
<p>Korean text you tap to hear is spoken by Apple’s on-device voice.</p>

<h2>AI tutor and grading</h2>
<p>When this build includes the Unbrick server, the text of your answer and the lesson prompt (not the audio) are sent to that server with the install id. The server forwards that text to Anthropic’s Claude API and returns the feedback. The server does not store the prompt, the answer, or the reply.</p>
<p>The server uses your IP address only as a one-minute rate-limit counter in memory. It does not save the IP as a profile and it does not turn it into a location. The install id is stored with a daily message count and with the shared spend total, so the tutor can stop at the daily cap. Message text is not stored with it. Daily install-id counts are dropped after a few days. The spend total is one number for the whole service, not a record of who you are.</p>
<p>If the server’s budget is used up, or this build has no server, and Apple Intelligence is available, grading can run on the device. That on-device pass is not sent to Anthropic.</p>
<p>Anthropic’s terms apply to text that reaches Claude. See <a href="https://www.anthropic.com/legal/privacy">Anthropic’s privacy policy</a>.</p>

<h2>Notifications</h2>
<p>If you allow notifications, Unbrick schedules one local alert for the moment an unlock timer ends. There is no remote push, and Unbrick does not receive a push token.</p>

<h2>Practice tiles and Screen Time</h2>
<p>Tiles named for other apps are practice shortcuts inside Unbrick. Tapping one does not close or shield that app. This build does not use Apple’s Family Controls API. Limiting other apps is something you can set up yourself in iOS Settings under Screen Time. Unbrick can store the passcode you create and show it after you finish a practice session.</p>

<h2>Android</h2>
<p>The Android scaffold, if you install it, sends the same kind of tutor text and an install id to the same server. It does not block other apps. It is not the App Store app.</p>

<h2>Children</h2>
<p>Unbrick is not directed at children under 13. Do not use it for a child if you are not comfortable with speech recognition and, when the server is on, answer text being sent as described above.</p>

<h2>Deletion</h2>
<p>There is no account to delete. Delete the app to remove on-device progress, the passcode, the install id, and temporary recordings. The server has no profile to erase. Email <a href="mailto:${EMAIL}">${EMAIL}</a> if you want to ask what the server holds.</p>

<h2>Tracking</h2>
<p>Unbrick does not track you, does not use the advertising identifier, and does not use your data for advertising.</p>`,
);

export const supportHtml = page(
  "Unbrick support",
  `<h1>Unbrick support</h1>
<p>Unbrick: Learn Korean is published by <strong>${PUBLISHER}</strong>. Email <a href="mailto:${EMAIL}">${EMAIL}</a> and include your iOS version and what you were doing. There is no account to sign in to, and there is no in-app purchase to refund.</p>

<h2>Using the app</h2>
<ul>
  <li>Lessons, cards, and the calendar work without an account. Progress stays on the iPhone.</li>
  <li>The AI tutor is on the Home screen, labeled “AI tutor”. You can type or speak a Korean answer. The first time, iOS asks for the microphone and for speech recognition.</li>
  <li>If Apple Intelligence is on, the phone can grade on the device. A build that includes the Unbrick server sends the answer text there, then to Anthropic, and shows “AI tutor is resting, try again tomorrow” when the shared daily budget or the per-device cap is used up.</li>
  <li>Practice tiles do not close other apps. Screen Time limits are optional and are set in the Settings app. This build does not request Family Controls.</li>
</ul>

<h2>Privacy</h2>
<p>The <a href="/privacy">privacy policy</a> describes the microphone, speech, tutor text, the install id used for the daily cap, and local storage. To remove everything the app stored, delete Unbrick. There is no separate account to delete.</p>

<p>Last updated ${UPDATED}.</p>`,
);

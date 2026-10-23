# Unbrick API

A Cloudflare Worker that holds the Anthropic key and answers the iOS and Android apps. The app never sees the key. It sends `POST /v1/task` with a task name (`judge`, `tutor`, or `cards`), the lesson prompt, and the conversation. The worker picks the model, attaches the JSON schema, and rate-limits by IP.

Deploy this on Cloudflare Workers. The rate limit uses `CF-Connecting-IP`, which Cloudflare sets and the client cannot forge.

## Environment

| Name | Required | Purpose |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | yes | Anthropic secret. Set with `npx wrangler secret put ANTHROPIC_API_KEY`. |
| `APP_TOKEN` | yes | Shared with the app (`UNBRICK_APP_TOKEN`). Not the Anthropic key. Stops anonymous use of the URL. It will be inside the app binary, so treat it as a speed bump. Set with `npx wrangler secret put APP_TOKEN`. |
| `ANTHROPIC_MODEL` | no | Default `claude-opus-5-5`. `claude-haiku-5-5` or `claude-sonnet-5-5` are cheaper for short grades. |
| `ANTHROPIC_VERSION` | no | Default `2023-06-01`. |
| `ANTHROPIC_BETA` | no | Sent only when set. The old client used `server-side-fallback-2026-07-01`. Leave empty unless you need that header. |
| `MAX_TOKENS` | no | Default `4096`, capped at `8000`. Adaptive thinking shares this budget. Raise it if replies come back truncated. |
| `RATE_LIMIT_PER_MINUTE` | no | Default `12` requests per IP per minute, capped at 60. |

`wrangler.toml` may hold the non-secret vars. Do not put `ANTHROPIC_API_KEY` or `APP_TOKEN` in it. Local secrets go in `.dev.vars` (gitignored). Copy `.dev.vars.example`.

## Run

```bash
cd backend
npm test
npx wrangler dev
npx wrangler deploy
```

`GET /health` returns `{ "ok": true, "configured": true }` when both secrets are present. It does not check that the Anthropic key is valid.

The same `APP_TOKEN` value goes in `Unbrick/Config/Info.plist` as `UNBRICK_APP_TOKEN`, and the worker URL (no trailing path) goes in `UNBRICK_API_BASE`. Android reads the same pair from `android/local.properties`. See `LAUNCH.md`.

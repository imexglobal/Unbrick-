# Unbrick API

A Cloudflare Worker that holds the Anthropic key and answers the iOS and Android apps. The app never sees the key. It sends `POST /v1/task` with a task name (`judge`, `tutor`, or `cards`), the lesson prompt, and the conversation. The worker picks the model, attaches the JSON schema, rate-limits by IP, and stops when the spend caps are hit.

Deploy this on Cloudflare Workers. The rate limit uses `CF-Connecting-IP`, which Cloudflare sets and the client cannot forge.

Spend is stored in one Durable Object (`SPEND` / `SpendGuard`). Each call reserves an upper bound before Anthropic is contacted, then the reservation is replaced by the actual token cost from the response (or released if the call fails). KV is not used: it is eventually consistent, so two requests at once could both pass a hard cap. If the `SPEND` binding is missing, the worker returns 503 and does not call Anthropic.

When the daily cap, the total cap, or a device's daily message cap is hit, the worker returns HTTP 429 with `error.code` `resting` and the message `AI tutor is resting, try again tomorrow`.

## Environment

| Name | Required | Purpose |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | yes | Anthropic secret. Set with `npx wrangler secret put ANTHROPIC_API_KEY`. |
| `APP_TOKEN` | yes | Shared with the app (`UNBRICK_APP_TOKEN`). Not the Anthropic key. Stops anonymous use of the URL. It will be inside the app binary, so treat it as a speed bump. Set with `npx wrangler secret put APP_TOKEN`. |
| `ANTHROPIC_MODEL` | no | Default `claude-haiku-5-5`. Effort is forced to `low`. History is trimmed to the last 6 messages, 800 characters each, and the lesson prompt to 4,000 characters. |
| `ANTHROPIC_VERSION` | no | Default `2023-06-01`. |
| `ANTHROPIC_BETA` | no | Sent only when set. Leave empty unless you need that header. |
| `MAX_TOKENS` | no | Default `1024`, hard ceiling `2048`. Adaptive thinking shares this budget. |
| `RATE_LIMIT_PER_MINUTE` | no | Default `12` requests per IP per minute, capped at 60. |
| `DAILY_BUDGET_USD` | no | Default `0.55`. Global spend allowed per UTC day. About US$100 over 6 months at this pace. |
| `TOTAL_BUDGET_USD` | no | Default `100`. Global spend that is never reset. |
| `DEVICE_DAILY_LIMIT` | no | Default `30` successful messages per device per UTC day, on top of the IP limit. The app sends `X-Unbrick-Device`. |
| `PRICE_INPUT_PER_MTOK` | no | Default `0.10`. Dollars per million fresh input tokens. Haiku 5.5, prompts ≤100k, as of 2026-10-07. |
| `PRICE_OUTPUT_PER_MTOK` | no | Default `0.50`. Dollars per million output tokens, including thinking. |
| `PRICE_CACHE_WRITE_PER_MTOK` | no | Default `0.20`. The 1-hour Haiku cache-write rate, so a later cache cannot be undercounted. |
| `PRICE_CACHE_READ_PER_MTOK` | no | Default `0.01`. |
| `RESERVE_TOKENS_PER_CHAR` | no | Default `2`. Characters in the outgoing JSON are reserved as this many input tokens, priced at the higher of the input and cache-write rates, plus `MAX_TOKENS` of output. |

Changing `ANTHROPIC_MODEL` without changing `PRICE_*` makes the guard underestimate the invoice. Haiku 4.5 is a different, more expensive model.

`wrangler.toml` may hold the non-secret vars. Do not put `ANTHROPIC_API_KEY` or `APP_TOKEN` in it. Local secrets go in `.dev.vars` (gitignored). Copy `.dev.vars.example`.

## Run

```bash
cd backend
npm test
npx wrangler dev
npx wrangler deploy
```

The first deploy applies the `v1` migration that creates `SpendGuard`. Leave that block in `wrangler.toml`.

`GET /health` returns `{ "ok": true, "configured": true, "spendGuard": true }` when both secrets are present and the Durable Object binding is there. It does not check that the Anthropic key is valid.

`GET /privacy` and `GET /support` are public HTML pages (IMEX Global, hellopawfend@gmail.com). They do not require the app token. The iOS app links to them.

The same `APP_TOKEN` value goes in `Unbrick/Config/Info.plist` as `UNBRICK_APP_TOKEN`, and the worker URL (no trailing path) goes in `UNBRICK_API_BASE`. Android reads the same pair from `android/local.properties`. See `LAUNCH.md`.

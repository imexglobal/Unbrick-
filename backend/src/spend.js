/**
 * Hard spend ledger for the Unbrick proxy.
 *
 * A request reserves an upper bound before Anthropic is called, then the
 * reservation is replaced by the actual usage cost (or released on failure).
 * Money is integer microdollars: tokens × dollars-per-million-tokens.
 * One Durable Object serializes every reserve so two calls cannot both pass.
 */

export const RESTING_MESSAGE = "AI tutor is resting, try again tomorrow";

export const RESERVATION_TTL_MS = 3 * 60 * 1000;

export const DEFAULT_PRICES = {
  input: 0.1,
  output: 0.5,
  cacheWrite: 0.2,
  cacheRead: 0.01,
};

export function emptyLedger() {
  return { totalMicro: 0, reservedMicro: 0, reservations: {}, days: {} };
}

export function dayKey(now) {
  return new Date(now).toISOString().slice(0, 10);
}

function tokenCount(value) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

function priceMilli(pricePerMtok) {
  const n = Number(pricePerMtok);
  if (!Number.isFinite(n) || n <= 0) return 0;
  return Math.round(n * 1000);
}

/** Microdollars for `tokens` at `pricePerMtok` dollars per million tokens. */
export function microFromTokens(tokens, pricePerMtok) {
  const t = tokenCount(tokens);
  const milli = priceMilli(pricePerMtok);
  if (t === 0 || milli === 0) return 0;
  return Math.ceil((t * milli) / 1000);
}

export function usdToMicro(value, fallback) {
  const raw = value == null || value === "" ? fallback : Number(value);
  const n = Number.isFinite(raw) && raw >= 0 ? raw : fallback;
  return Math.round(n * 1_000_000);
}

/** Defaults pace US$100 across about six months: US$0.55 per UTC day, US$100 total. */
export function budgetConfig(env = {}) {
  const prices = {
    input: numberOr(env.PRICE_INPUT_PER_MTOK, DEFAULT_PRICES.input),
    output: numberOr(env.PRICE_OUTPUT_PER_MTOK, DEFAULT_PRICES.output),
    cacheWrite: numberOr(env.PRICE_CACHE_WRITE_PER_MTOK, DEFAULT_PRICES.cacheWrite),
    cacheRead: numberOr(env.PRICE_CACHE_READ_PER_MTOK, DEFAULT_PRICES.cacheRead),
  };
  return {
    dailyMicro: usdToMicro(env.DAILY_BUDGET_USD, 0.55),
    totalMicro: usdToMicro(env.TOTAL_BUDGET_USD, 100),
    deviceDailyLimit: Math.max(1, Math.floor(numberOr(env.DEVICE_DAILY_LIMIT, 30))),
    tokensPerChar: Math.max(1, numberOr(env.RESERVE_TOKENS_PER_CHAR, 2)),
    prices,
  };
}

function numberOr(value, fallback) {
  if (value == null || value === "") return fallback;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

export function usageCostMicro(usage, prices = DEFAULT_PRICES) {
  if (!usage || typeof usage !== "object") return 0;
  return (
    microFromTokens(usage.input_tokens, prices.input) +
    microFromTokens(usage.output_tokens, prices.output) +
    microFromTokens(usage.cache_creation_input_tokens, prices.cacheWrite) +
    microFromTokens(usage.cache_read_input_tokens, prices.cacheRead)
  );
}

/**
 * Upper bound for a call that has not run yet.
 * Characters are counted as `tokensPerChar` tokens (default 2) so Korean
 * cannot slip under the cap, and the input side uses the higher of the
 * fresh-input and cache-write prices.
 */
export function estimateReserveMicro(charLength, maxTokens, cfg) {
  const perChar = Math.max(1, Number(cfg.tokensPerChar) || 1);
  const chars = Math.max(1, Math.ceil(Number(charLength) || 0));
  const inputTokens = Math.ceil(chars * perChar);
  const inputRate = Math.max(Number(cfg.prices.input) || 0, Number(cfg.prices.cacheWrite) || 0);
  return microFromTokens(inputTokens, inputRate) + microFromTokens(maxTokens, cfg.prices.output);
}

function dayBucket(ledger, day) {
  if (!ledger.days[day]) ledger.days[day] = { spentMicro: 0, reservedMicro: 0, devices: {} };
  return ledger.days[day];
}

function releaseReservation(ledger, id) {
  const res = ledger.reservations[id];
  if (!res) return false;
  ledger.reservedMicro = Math.max(0, ledger.reservedMicro - res.micro);
  const bucket = ledger.days[res.day];
  if (bucket) {
    bucket.reservedMicro = Math.max(0, bucket.reservedMicro - res.micro);
    if (bucket.devices[res.device]) bucket.devices[res.device] = Math.max(0, bucket.devices[res.device] - 1);
  }
  delete ledger.reservations[id];
  return true;
}

function expire(ledger, now, keepId) {
  for (const [id, res] of Object.entries(ledger.reservations)) {
    if (id === keepId) continue;
    if (now - res.at >= RESERVATION_TTL_MS) releaseReservation(ledger, id);
  }
  const cutoff = dayKey(now - 3 * 86_400_000);
  for (const day of Object.keys(ledger.days)) {
    if (day >= cutoff) continue;
    const still = Object.values(ledger.reservations).some((res) => res.day === day);
    if (!still) delete ledger.days[day];
  }
}

export function reserve(ledger, input, now) {
  expire(ledger, now);
  const day = dayKey(now);
  const bucket = dayBucket(ledger, day);
  const count = bucket.devices[input.device] || 0;
  if (count >= input.deviceDailyLimit) return { ok: false, reason: "device" };
  const micro = Math.max(0, Math.ceil(Number(input.reserveMicro) || 0));
  if (ledger.totalMicro + ledger.reservedMicro + micro > input.totalMicro) return { ok: false, reason: "total" };
  if (bucket.spentMicro + bucket.reservedMicro + micro > input.dailyMicro) return { ok: false, reason: "daily" };
  const id = input.id || crypto.randomUUID();
  ledger.reservedMicro += micro;
  bucket.reservedMicro += micro;
  bucket.devices[input.device] = count + 1;
  ledger.reservations[id] = { micro, device: input.device, day, at: now };
  return { ok: true, id, reservedMicro: micro };
}

export function commit(ledger, input, now) {
  const actual = usageCostMicro(input.usage, input.prices);
  expire(ledger, now, input.id);
  const res = ledger.reservations[input.id];
  if (!res) {
    const bucket = dayBucket(ledger, dayKey(now));
    ledger.totalMicro += actual;
    bucket.spentMicro += actual;
    return { ok: true, actualMicro: actual, late: true };
  }
  ledger.reservedMicro = Math.max(0, ledger.reservedMicro - res.micro);
  const bucket = dayBucket(ledger, res.day);
  bucket.reservedMicro = Math.max(0, bucket.reservedMicro - res.micro);
  ledger.totalMicro += actual;
  bucket.spentMicro += actual;
  delete ledger.reservations[input.id];
  return { ok: true, actualMicro: actual };
}

export function release(ledger, input, now) {
  expire(ledger, now, input.id);
  return { ok: releaseReservation(ledger, input.id) };
}

export function createLedger(nowFn = () => Date.now()) {
  const ledger = emptyLedger();
  return {
    reserve(input) {
      return Promise.resolve(reserve(ledger, input, nowFn()));
    },
    commit(input) {
      return Promise.resolve(commit(ledger, input, nowFn()));
    },
    release(input) {
      return Promise.resolve(release(ledger, input, nowFn()));
    },
    snapshot() {
      return Promise.resolve(JSON.parse(JSON.stringify(ledger)));
    },
  };
}

export class SpendGuard {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(request) {
    const op = new URL(request.url).pathname.replace(/^\//, "");
    let ledger = (await this.ctx.storage.get("ledger")) || emptyLedger();
    const body = request.method === "GET" ? {} : await request.json();
    const now = Date.now();
    let result;
    if (op === "reserve") result = reserve(ledger, body, now);
    else if (op === "commit") result = commit(ledger, body, now);
    else if (op === "release") result = release(ledger, body, now);
    else if (op === "snapshot") result = ledger;
    else return new Response(JSON.stringify({ error: "not_found" }), { status: 404 });
    await this.ctx.storage.put("ledger", ledger);
    return new Response(JSON.stringify(result), {
      headers: { "content-type": "application/json; charset=utf-8" },
    });
  }
}

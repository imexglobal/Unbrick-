import assert from "node:assert/strict";
import test from "node:test";
import { createLedger } from "../src/spend.js";
import { handleRequest, resetRateLimits, trimForModel, validateTask } from "../src/worker.js";

const env = {
  APP_TOKEN: "test-token",
  ANTHROPIC_API_KEY: "sk-ant-test-secret",
  ANTHROPIC_MODEL: "claude-opus-5-5",
  RATE_LIMIT_PER_MINUTE: "2",
  MAX_TOKENS: "1024",
};

const DEVICE = "device-test-1";

function post(body, { token = env.APP_TOKEN, ip = "203.0.113.10", device = DEVICE } = {}) {
  const headers = {
    "content-type": "application/json",
    "x-unbrick-token": token,
    "CF-Connecting-IP": ip,
  };
  if (device != null) headers["x-unbrick-device"] = device;
  return new Request("https://unbrick.test/v1/task", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function deps(extra = {}) {
  const now = extra.now || (() => Date.now());
  return { ledger: extra.ledger || createLedger(now), ...extra };
}

const judgeBody = {
  task: "judge",
  system: "Grade this Korean answer.",
  messages: [{ role: "user", content: "Learner said: 안녕하세요" }],
  effort: "low",
  model: "claude-should-be-ignored",
  max_tokens: 999999,
};

function upstreamOk(text, usage) {
  return new Response(JSON.stringify({
    stop_reason: "end_turn",
    usage: usage || { input_tokens: 12, output_tokens: 8 },
    content: [
      { type: "thinking", thinking: "hidden" },
      { type: "text", text },
    ],
  }), { status: 200, headers: { "content-type": "application/json" } });
}

test("health does not require a token and does not leak the key", async () => {
  const res = await handleRequest(new Request("https://unbrick.test/health"), env);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.configured, true);
  assert.equal(body.spendGuard, false);
  assert.equal(JSON.stringify(body).includes("sk-ant"), false);
  const guarded = await handleRequest(new Request("https://unbrick.test/health"), env, { ledger: createLedger() });
  assert.equal((await guarded.json()).spendGuard, true);
});

test("rejects a missing or wrong app token", async () => {
  resetRateLimits();
  const missing = await handleRequest(post(judgeBody, { token: "" }), env);
  assert.equal(missing.status, 401);
  const wrong = await handleRequest(post(judgeBody, { token: "nope" }), env);
  assert.equal(wrong.status, 401);
});

test("refuses to run when the Anthropic key is not configured", async () => {
  const res = await handleRequest(post(judgeBody), { APP_TOKEN: "test-token" });
  assert.equal(res.status, 503);
  assert.equal((await res.json()).error.code, "not_configured");
});

test("validateTask drops a leading assistant turn and rejects a trailing one", () => {
  const ok = validateTask({
    task: "tutor",
    system: "Tutor.",
    messages: [
      { role: "assistant", content: "ignore" },
      { role: "user", content: "Start." },
    ],
  });
  assert.equal(ok.value.messages.length, 1);
  assert.equal(ok.value.effort, "low");
  const bad = validateTask({
    task: "tutor",
    system: "Tutor.",
    messages: [{ role: "user", content: "Hi" }, { role: "assistant", content: "prefill" }],
  });
  assert.match(bad.error, /end with a user/);
});

test("trimForModel keeps the last six turns, the tail of each, and forces low effort", () => {
  const messages = [];
  for (let i = 0; i < 9; i++) {
    messages.push({ role: i % 2 === 0 ? "user" : "assistant", content: "m".repeat(1000) + String(i) });
  }
  const trimmed = trimForModel({ task: "tutor", system: "S".repeat(5000), messages, effort: "medium" });
  assert.equal(trimmed.effort, "low");
  assert.equal(trimmed.system.length, 4000);
  assert.equal(trimmed.messages.length, 5);
  assert.equal(trimmed.messages[0].role, "user");
  assert.equal(trimmed.messages.at(-1).role, "user");
  assert.equal(trimmed.messages.at(-1).content.endsWith("8"), true);
  assert.ok(trimmed.messages.every((message) => message.content.length === 800));
});

test("forwards only the server model and schema, then returns the parsed JSON", async () => {
  resetRateLimits();
  let seen;
  const fetch = async (url, init) => {
    seen = { url, body: JSON.parse(init.body), headers: init.headers };
    return upstreamOk(JSON.stringify({
      correct: true, feedback: "좋아요", fix: "", mistakes: [], grammar: "",
    }));
  };
  const res = await handleRequest(post(judgeBody, { ip: "203.0.113.20" }), env, deps({ fetch, now: () => 1_700_000_000_000 }));
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.correct, true);
  assert.equal(seen.url, "https://api.anthropic.com/v1/messages");
  assert.equal(seen.body.model, "claude-opus-5-5");
  assert.equal(seen.body.max_tokens, 1024);
  assert.equal(seen.body.output_config.effort, "low");
  assert.equal(seen.body.temperature, undefined);
  assert.equal(seen.headers["x-api-key"], env.ANTHROPIC_API_KEY);
  assert.equal(seen.body.output_config.format.type, "json_schema");
  assert.equal(seen.body.output_config.format.schema.properties.correct.type, "boolean");
  assert.match(seen.body.system, /^You are Unbrick/);
  assert.equal(JSON.stringify(body).includes(env.ANTHROPIC_API_KEY), false);
});

test("defaults to Haiku, clamps max tokens, and trims history before the upstream call", async () => {
  resetRateLimits();
  let seen;
  const messages = [];
  for (let i = 0; i < 9; i++) {
    messages.push({ role: i % 2 === 0 ? "user" : "assistant", content: "m".repeat(900) + String(i) });
  }
  const fetch = async (_url, init) => {
    seen = JSON.parse(init.body);
    return upstreamOk("{}");
  };
  const bare = { ...env };
  delete bare.ANTHROPIC_MODEL;
  delete bare.MAX_TOKENS;
  const res = await handleRequest(post({
    task: "tutor",
    system: "S".repeat(4500),
    messages,
    effort: "medium",
  }, { ip: "203.0.113.23" }), bare, deps({ fetch, now: () => 1_700_000_240_000 }));
  assert.equal(res.status, 200);
  assert.equal(seen.model, "claude-haiku-5-5");
  assert.equal(seen.max_tokens, 1024);
  assert.equal(seen.output_config.effort, "low");
  assert.equal(seen.messages.length, 5);
  assert.equal(seen.system.length, "You are Unbrick".length > 0 ? seen.system.indexOf("S".repeat(40)) + 4000 : 0);
  assert.ok(seen.system.endsWith("S".repeat(40)));
  assert.equal(seen.system.slice(seen.system.indexOf("SSSS")).length, 4000);

  resetRateLimits();
  const clamped = { ...bare, MAX_TOKENS: "9000" };
  await handleRequest(post(judgeBody, { ip: "203.0.113.24" }), clamped, deps({
    fetch: async (_url, init) => {
      seen = JSON.parse(init.body);
      return upstreamOk("{}");
    },
    now: () => 1_700_000_300_000,
  }));
  assert.equal(seen.max_tokens, 2048);
});

test("maps refusal and upstream rate limits", async () => {
  resetRateLimits();
  const refused = await handleRequest(post(judgeBody, { ip: "203.0.113.21" }), env, deps({
    now: () => 1_700_000_060_000,
    fetch: async () => new Response(JSON.stringify({
      stop_reason: "refusal",
      usage: { input_tokens: 30, output_tokens: 4 },
      content: [],
    }), { status: 200 }),
  }));
  assert.equal(refused.status, 422);
  const limited = await handleRequest(post(judgeBody, { ip: "203.0.113.22" }), env, deps({
    now: () => 1_700_000_120_000,
    fetch: async () => new Response(JSON.stringify({ error: { message: "slow down sk-ant-test-secret" } }), { status: 429 }),
  }));
  assert.equal(limited.status, 429);
  const text = await limited.text();
  assert.equal(JSON.parse(text).error.code, "rate_limited");
  assert.equal(text.includes("sk-ant"), false);
});

test("a refusal that was billed stays on the ledger", async () => {
  resetRateLimits();
  const ledger = createLedger(() => 1_700_000_360_000);
  const res = await handleRequest(post(judgeBody, { ip: "203.0.113.25" }), env, deps({
    ledger,
    now: () => 1_700_000_360_000,
    fetch: async () => new Response(JSON.stringify({
      stop_reason: "refusal",
      usage: { input_tokens: 100, output_tokens: 20 },
      content: [],
    }), { status: 200 }),
  }));
  assert.equal(res.status, 422);
  const snap = await ledger.snapshot();
  assert.equal(snap.totalMicro, 10 + 10);
  assert.equal(snap.reservedMicro, 0);
  assert.equal(snap.days["2023-11-14"].devices[DEVICE], 1);
});

test("rate limit trips before calling upstream", async () => {
  resetRateLimits();
  let calls = 0;
  const ip = "203.0.113.30";
  const shared = deps({
    now: () => 1_700_000_180_000,
    fetch: async () => {
      calls += 1;
      return upstreamOk("{}");
    },
  });
  assert.equal((await handleRequest(post(judgeBody, { ip }), env, shared)).status, 200);
  assert.equal((await handleRequest(post(judgeBody, { ip }), env, shared)).status, 200);
  const blocked = await handleRequest(post(judgeBody, { ip }), env, shared);
  assert.equal(blocked.status, 429);
  assert.equal((await blocked.json()).error.code, "rate_limited");
  assert.equal(calls, 2);
});

test("unknown routes and bad tasks do not call upstream", async () => {
  let calls = 0;
  const shared = deps({ fetch: async () => { calls += 1; return upstreamOk("{}"); } });
  const missing = await handleRequest(new Request("https://unbrick.test/v1/messages", { method: "POST" }), env, shared);
  assert.equal(missing.status, 404);
  resetRateLimits();
  const bad = await handleRequest(post({ task: "chat", system: "x", messages: [{ role: "user", content: "hi" }] }, { ip: "203.0.113.40" }), env, shared);
  assert.equal(bad.status, 400);
  assert.equal(calls, 0);
});

test("a missing device id or a missing ledger never calls Anthropic", async () => {
  resetRateLimits();
  let calls = 0;
  const fetch = async () => {
    calls += 1;
    return upstreamOk("{}");
  };
  const noDevice = await handleRequest(post(judgeBody, { ip: "203.0.113.41", device: "" }), env, deps({ fetch, now: () => 1_700_000_420_000 }));
  assert.equal(noDevice.status, 400);
  assert.equal((await noDevice.json()).error.code, "bad_device");
  resetRateLimits();
  const noLedger = await handleRequest(post(judgeBody, { ip: "203.0.113.42" }), env, { fetch, now: () => 1_700_000_480_000 });
  assert.equal(noLedger.status, 503);
  assert.equal((await noLedger.json()).error.code, "spend_guard");
  assert.equal(calls, 0);
});

test("daily cap, total cap, and the per-device cap rest the tutor without calling upstream", async () => {
  resetRateLimits();
  let calls = 0;
  const fetch = async () => {
    calls += 1;
    return upstreamOk("{}");
  };
  const daily = await handleRequest(post(judgeBody, { ip: "203.0.113.50" }), {
    ...env,
    DAILY_BUDGET_USD: "0",
  }, deps({ fetch, now: () => 1_700_000_540_000 }));
  assert.equal(daily.status, 429);
  const dailyBody = await daily.json();
  assert.equal(dailyBody.error.code, "resting");
  assert.equal(dailyBody.error.reason, "daily");
  assert.equal(dailyBody.error.message, "AI tutor is resting, try again tomorrow");

  resetRateLimits();
  const total = await handleRequest(post(judgeBody, { ip: "203.0.113.51" }), {
    ...env,
    TOTAL_BUDGET_USD: "0",
  }, deps({ fetch, now: () => 1_700_000_600_000 }));
  assert.equal((await total.json()).error.reason, "total");

  resetRateLimits();
  const ledger = createLedger(() => 1_700_000_660_000);
  const limited = { ...env, DEVICE_DAILY_LIMIT: "1" };
  const shared = deps({
    ledger,
    now: () => 1_700_000_660_000,
    fetch,
  });
  assert.equal((await handleRequest(post(judgeBody, { ip: "203.0.113.52" }), limited, shared)).status, 200);
  const device = await handleRequest(post(judgeBody, { ip: "203.0.113.53" }), limited, shared);
  const deviceBody = await device.json();
  assert.equal(device.status, 429);
  assert.equal(deviceBody.error.code, "resting");
  assert.equal(deviceBody.error.reason, "device");
  assert.equal(deviceBody.error.message, "AI tutor is resting, try again tomorrow");
  assert.equal(calls, 1);
});

test("usage from a successful call is recorded at the configured price", async () => {
  resetRateLimits();
  const ledger = createLedger(() => 1_700_000_720_000);
  const res = await handleRequest(post(judgeBody, { ip: "203.0.113.60" }), {
    ...env,
    PRICE_INPUT_PER_MTOK: "0.10",
    PRICE_OUTPUT_PER_MTOK: "1",
  }, deps({
    ledger,
    now: () => 1_700_000_720_000,
    fetch: async () => upstreamOk("{}", { input_tokens: 100, output_tokens: 20, cache_read_input_tokens: 50 }),
  }));
  assert.equal(res.status, 200);
  const snap = await ledger.snapshot();
  assert.equal(snap.totalMicro, 10 + 20 + 1);
  assert.equal(snap.reservedMicro, 0);
});

test("an upstream failure releases the reservation so a later call still fits", async () => {
  resetRateLimits();
  const now = 1_700_000_780_000;
  const ledger = createLedger(() => now);
  const tight = { ...env, DEVICE_DAILY_LIMIT: "1" };
  let calls = 0;
  const failed = await handleRequest(post(judgeBody, { ip: "203.0.113.70" }), tight, deps({
    ledger,
    now: () => now,
    fetch: async () => {
      calls += 1;
      throw new Error("down");
    },
  }));
  assert.equal(failed.status, 502);
  const after = await ledger.snapshot();
  assert.equal(after.reservedMicro, 0);
  assert.equal(after.totalMicro, 0);
  assert.equal(after.days["2023-11-14"].devices[DEVICE], 0);

  const again = await handleRequest(post(judgeBody, { ip: "203.0.113.71" }), tight, deps({
    ledger,
    now: () => now,
    fetch: async () => {
      calls += 1;
      return upstreamOk("{}");
    },
  }));
  assert.equal(again.status, 200);
  assert.equal(calls, 2);
  const booked = await ledger.snapshot();
  assert.ok(booked.totalMicro > 0);
  assert.equal(booked.reservedMicro, 0);
});

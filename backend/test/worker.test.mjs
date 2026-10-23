import assert from "node:assert/strict";
import test from "node:test";
import { handleRequest, resetRateLimits, validateTask } from "../src/worker.js";

const env = {
  APP_TOKEN: "test-token",
  ANTHROPIC_API_KEY: "sk-ant-test-secret",
  ANTHROPIC_MODEL: "claude-opus-5-5",
  RATE_LIMIT_PER_MINUTE: "2",
  MAX_TOKENS: "1024",
};

function post(body, { token = env.APP_TOKEN, ip = "203.0.113.10" } = {}) {
  return new Request("https://unbrick.test/v1/task", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-unbrick-token": token,
      "CF-Connecting-IP": ip,
    },
    body: JSON.stringify(body),
  });
}

const judgeBody = {
  task: "judge",
  system: "Grade this Korean answer.",
  messages: [{ role: "user", content: "Learner said: 안녕하세요" }],
  effort: "low",
  model: "claude-should-be-ignored",
  max_tokens: 999999,
};

function upstreamOk(text) {
  return new Response(JSON.stringify({
    stop_reason: "end_turn",
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
  assert.equal(JSON.stringify(body).includes("sk-ant"), false);
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

test("forwards only the server model and schema, then returns the parsed JSON", async () => {
  resetRateLimits();
  let seen;
  const fetch = async (url, init) => {
    seen = { url, body: JSON.parse(init.body), headers: init.headers };
    return upstreamOk(JSON.stringify({
      correct: true, feedback: "좋아요", fix: "", mistakes: [], grammar: "",
    }));
  };
  const res = await handleRequest(post(judgeBody, { ip: "203.0.113.20" }), env, { fetch, now: () => 1_700_000_000_000 });
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.correct, true);
  assert.equal(seen.url, "https://api.anthropic.com/v1/messages");
  assert.equal(seen.body.model, "claude-opus-5-5");
  assert.equal(seen.body.max_tokens, 1024);
  assert.equal(seen.body.temperature, undefined);
  assert.equal(seen.headers["x-api-key"], env.ANTHROPIC_API_KEY);
  assert.equal(seen.body.output_config.format.type, "json_schema");
  assert.equal(seen.body.output_config.format.schema.properties.correct.type, "boolean");
  assert.match(seen.body.system, /^You are Unbrick/);
  assert.equal(JSON.stringify(body).includes(env.ANTHROPIC_API_KEY), false);
});

test("maps refusal and upstream rate limits", async () => {
  resetRateLimits();
  const refused = await handleRequest(post(judgeBody, { ip: "203.0.113.21" }), env, {
    now: () => 1_700_000_060_000,
    fetch: async () => new Response(JSON.stringify({ stop_reason: "refusal", content: [] }), { status: 200 }),
  });
  assert.equal(refused.status, 422);
  const limited = await handleRequest(post(judgeBody, { ip: "203.0.113.22" }), env, {
    now: () => 1_700_000_120_000,
    fetch: async () => new Response(JSON.stringify({ error: { message: "slow down sk-ant-test-secret" } }), { status: 429 }),
  });
  assert.equal(limited.status, 429);
  const text = await limited.text();
  assert.equal(text.includes("sk-ant"), false);
});

test("rate limit trips before calling upstream", async () => {
  resetRateLimits();
  let calls = 0;
  const deps = {
    now: () => 1_700_000_180_000,
    fetch: async () => {
      calls += 1;
      return upstreamOk("{}");
    },
  };
  const ip = "203.0.113.30";
  assert.equal((await handleRequest(post(judgeBody, { ip }), env, deps)).status, 200);
  assert.equal((await handleRequest(post(judgeBody, { ip }), env, deps)).status, 200);
  const blocked = await handleRequest(post(judgeBody, { ip }), env, deps);
  assert.equal(blocked.status, 429);
  assert.equal(calls, 2);
});

test("unknown routes and bad tasks do not call upstream", async () => {
  let calls = 0;
  const deps = { fetch: async () => { calls += 1; return upstreamOk("{}"); } };
  const missing = await handleRequest(new Request("https://unbrick.test/v1/messages", { method: "POST" }), env, deps);
  assert.equal(missing.status, 404);
  resetRateLimits();
  const bad = await handleRequest(post({ task: "chat", system: "x", messages: [{ role: "user", content: "hi" }] }, { ip: "203.0.113.40" }), env, deps);
  assert.equal(bad.status, 400);
  assert.equal(calls, 0);
});

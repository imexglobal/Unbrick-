import assert from "node:assert/strict";
import test from "node:test";
import {
  SpendGuard,
  budgetConfig,
  commit,
  createLedger,
  emptyLedger,
  estimateReserveMicro,
  microFromTokens,
  reserve,
  usageCostMicro,
} from "../src/spend.js";

const prices = { input: 0.1, output: 0.5, cacheWrite: 0.2, cacheRead: 0.01 };
const now = Date.parse("2026-10-23T12:00:00Z");

function caps(over = {}) {
  return {
    dailyMicro: 1_000,
    totalMicro: 100_000_000,
    deviceDailyLimit: 30,
    ...over,
  };
}

test("microdollars match published per-million prices", () => {
  assert.equal(microFromTokens(1_000, 0.1), 100);
  assert.equal(microFromTokens(1_000, 0.5), 500);
  assert.equal(microFromTokens(1, 0.1), 1);
  assert.equal(microFromTokens(0, 0.5), 0);
  const usage = usageCostMicro({
    input_tokens: 1_000,
    output_tokens: 20,
    cache_creation_input_tokens: 1_000,
    cache_read_input_tokens: 1_000,
  }, prices);
  assert.equal(usage, 100 + 10 + 200 + 10);
});

test("defaults are the $0.55 daily pace and the $100 ceiling", () => {
  const cfg = budgetConfig({});
  assert.equal(cfg.dailyMicro, 550_000);
  assert.equal(cfg.totalMicro, 100_000_000);
  assert.equal(cfg.deviceDailyLimit, 30);
  assert.equal(cfg.tokensPerChar, 2);
  assert.equal(cfg.prices.input, 0.1);
  assert.equal(cfg.prices.output, 0.5);
  assert.equal(cfg.prices.cacheWrite, 0.2);
  assert.equal(cfg.prices.cacheRead, 0.01);
});

test("reserve prices the body at the higher input rate plus max output", () => {
  const cfg = budgetConfig({});
  const micro = estimateReserveMicro(100, 10, cfg);
  // 100 chars × 2 tokens × $0.20 cache-write rate, plus 10 output × $0.50.
  assert.equal(micro, 40 + 5);
});

test("daily cap rejects the reservation that would cross it", () => {
  const ledger = emptyLedger();
  const first = reserve(ledger, { ...caps(), device: "device-1", reserveMicro: 800, id: "a" }, now);
  assert.equal(first.ok, true);
  const second = reserve(ledger, { ...caps(), device: "device-2", reserveMicro: 300, id: "b" }, now);
  assert.equal(second.ok, false);
  assert.equal(second.reason, "daily");
  assert.equal(ledger.reservedMicro, 800);
});

test("total cap counts committed spend plus outstanding reservations", () => {
  const ledger = emptyLedger();
  const first = reserve(ledger, { ...caps({ totalMicro: 1_000, dailyMicro: 50_000 }), device: "device-1", reserveMicro: 400, id: "a" }, now);
  commit(ledger, { id: first.id, usage: { input_tokens: 100, output_tokens: 0 }, prices }, now);
  assert.equal(ledger.totalMicro, 10);
  assert.equal(ledger.reservedMicro, 0);
  const room = reserve(ledger, { ...caps({ totalMicro: 1_000, dailyMicro: 50_000 }), device: "device-1", reserveMicro: 990, id: "b" }, now);
  assert.equal(room.ok, true);
  const over = reserve(ledger, { ...caps({ totalMicro: 1_000, dailyMicro: 50_000 }), device: "device-2", reserveMicro: 20, id: "c" }, now);
  assert.equal(over.ok, false);
  assert.equal(over.reason, "total");
});

test("device daily limit counts in-flight calls and a release gives the slot back", async () => {
  const ledger = createLedger(() => now);
  const cfg = caps({ deviceDailyLimit: 2, dailyMicro: 50_000 });
  assert.equal((await ledger.reserve({ ...cfg, device: "phone-1", reserveMicro: 10 })).ok, true);
  const second = await ledger.reserve({ ...cfg, device: "phone-1", reserveMicro: 10 });
  assert.equal(second.ok, true);
  const blocked = await ledger.reserve({ ...cfg, device: "phone-1", reserveMicro: 10 });
  assert.equal(blocked.ok, false);
  assert.equal(blocked.reason, "device");
  assert.equal((await ledger.reserve({ ...cfg, device: "phone-2", reserveMicro: 10 })).ok, true);
  await ledger.release({ id: second.id });
  const again = await ledger.reserve({ ...cfg, device: "phone-1", reserveMicro: 10 });
  assert.equal(again.ok, true);
});

test("commit replaces the reservation with actual usage, even when actual is higher", () => {
  const ledger = emptyLedger();
  reserve(ledger, { ...caps(), device: "device-1", reserveMicro: 5, id: "a" }, now);
  const done = commit(ledger, { id: "a", usage: { input_tokens: 100, output_tokens: 20 }, prices }, now);
  assert.equal(done.actualMicro, 10 + 10);
  assert.equal(ledger.totalMicro, 20);
  assert.equal(ledger.reservedMicro, 0);
  assert.equal(ledger.days["2026-10-23"].devices["device-1"], 1);
  assert.equal(ledger.reservations.a, undefined);
});

test("a reservation older than three minutes stops counting", () => {
  const ledger = emptyLedger();
  reserve(ledger, { ...caps({ deviceDailyLimit: 1, dailyMicro: 10 }), device: "device-1", reserveMicro: 10, id: "stuck" }, now);
  const later = now + 3 * 60 * 1000;
  const next = reserve(ledger, { ...caps({ deviceDailyLimit: 1, dailyMicro: 10 }), device: "device-1", reserveMicro: 10, id: "fresh" }, later);
  assert.equal(next.ok, true);
  assert.equal(ledger.reservations.stuck, undefined);
  assert.equal(ledger.days["2026-10-23"].devices["device-1"], 1);
});

test("SpendGuard persists the ledger across requests", async () => {
  const map = new Map();
  const guard = new SpendGuard({
    storage: {
      async get(key) { return map.get(key); },
      async put(key, value) { map.set(key, value); },
    },
  });
  const body = { ...caps(), device: "device-1", reserveMicro: 40 };
  const post = (op, payload) => new Request(`https://spend.internal/${op}`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
  const held = await (await guard.fetch(post("reserve", body))).json();
  assert.equal(held.ok, true);
  const committed = await (await guard.fetch(post("commit", {
    id: held.id,
    usage: { input_tokens: 100, output_tokens: 0 },
    prices,
  }))).json();
  assert.equal(committed.actualMicro, 10);
  const snap = await (await guard.fetch(new Request("https://spend.internal/snapshot"))).json();
  assert.equal(snap.totalMicro, 10);
  assert.equal(snap.reservedMicro, 0);
});

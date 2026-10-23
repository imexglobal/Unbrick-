import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const content = JSON.parse(readFileSync(new URL("../../Unbrick/Unbrick/Resources/Content.json", import.meta.url)));

test("bundled lessons match the fields the iOS decoder requires", () => {
  assert.equal(content.units.length, 16);
  assert.deepEqual(content.units.map((unit) => unit.n), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  for (const unit of content.units) {
    for (const key of ["ko", "en", "ru", "grammar", "pron", "me", "dialogue", "vocab", "sentences", "questions"]) {
      assert.ok(key in unit, `unit ${unit.n} missing ${key}`);
    }
    assert.ok(unit.pron.sentences.length > 0, `unit ${unit.n} has no pronunciation sentences`);
    for (const word of unit.vocab) {
      for (const key of ["ko", "en", "ru", "ex", "exen", "exru"]) assert.ok(key in word);
    }
  }
  assert.ok(content.society.length > 0);
  assert.ok(content.interview.length > 0);
  assert.ok(content.visa.length > 0);
});

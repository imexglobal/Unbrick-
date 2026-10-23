import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const content = JSON.parse(readFileSync(new URL("../../Unbrick/Unbrick/Resources/Content.json", import.meta.url)));

const expected = {
  0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  2: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  3: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
  4: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16],
  5: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
};

test("bundled lessons cover KIIP levels 0–5 and keep level 3", () => {
  assert.equal(content.units.length, 81);
  const seen = new Set();
  for (const level of Object.keys(expected)) {
    const numbers = content.units.filter((unit) => (unit.level ?? 3) === Number(level)).map((unit) => unit.n);
    assert.deepEqual(numbers, expected[level], `level ${level} unit numbers`);
  }
  for (const unit of content.units) {
    const level = unit.level ?? 3;
    const key = `${level}-${unit.n}`;
    assert.equal(seen.has(key), false, `duplicate ${key}`);
    seen.add(key);
    for (const field of ["ko", "en", "ru", "grammar", "pron", "me", "dialogue", "vocab", "sentences", "questions"]) {
      assert.ok(field in unit, `unit ${key} missing ${field}`);
    }
    assert.ok(unit.pron.sentences.length > 0, `unit ${key} has no pronunciation sentences`);
    assert.ok(unit.vocab.length >= 8, `unit ${key} has too little vocabulary`);
    assert.ok(unit.sentences.length >= 6, `unit ${key} has too few sentences`);
    assert.ok(unit.dialogue.length >= 4, `unit ${key} has too little dialogue`);
    assert.ok(unit.questions.length >= 4, `unit ${key} has too few questions`);
    assert.ok(unit.dialogue.some((line) => line.speaker === unit.me), `unit ${key} dialogue never uses ${unit.me}`);
    const names = new Set(unit.grammar.map((point) => point.name));
    for (const word of unit.vocab) {
      for (const field of ["ko", "en", "ru", "ex", "exen", "exru"]) assert.ok(field in word, `unit ${key} vocab`);
      if (level !== 3) {
        for (const field of ["ex", "exen", "exru"]) assert.ok(word[field], `unit ${key} example`);
      }
    }
    for (const sentence of unit.sentences) {
      assert.match(sentence.ko, /\[\[[^\]]+\]\]/);
      if (level !== 3) assert.ok(names.has(sentence.g), `unit ${key} sentence grammar`);
    }
    for (const point of unit.grammar) {
      assert.ok(point.forms.length >= 4, `unit ${key} grammar forms`);
      assert.ok(point.howEn && point.howRu && point.ko);
    }
    for (const question of unit.questions) {
      assert.ok(Array.isArray(question.k) && question.k.length > 0);
      assert.ok(question.k.every((item) => typeof item === "string" && item.length > 0));
    }
  }
  const level3 = content.units.find((unit) => unit.level === 3 && unit.n === 1);
  assert.equal(level3.ko, "대인 관계");
  assert.equal(level3.me, "잠시드");
  assert.equal(level3.grammar[0].name, "-고 해서");
  assert.ok(level3.sentences.some((sentence) => sentence.ko.includes("샌드위치")));
  for (const unit of content.units.filter((item) => item.level !== 3)) {
    assert.equal(unit.me, "안나");
  }
  assert.equal(content.units.some((unit) => unit.level === 4 && unit.n === 8), false);
  assert.ok(content.society.length > 0);
  assert.ok(content.interview.length > 0);
  assert.ok(content.visa.length > 0);
});

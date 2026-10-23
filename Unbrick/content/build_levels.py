#!/usr/bin/env python3
"""Stamp level 3 and append original lessons for KIIP levels 0, 1, 2, 4 and 5.

Topics follow publicly listed KIIP chapter themes. Sentences, dialogues and
explanations are original and are not copied from the textbooks.
Level 3 card text is left unchanged so existing review progress still matches.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Unbrick" / "Resources" / "Content.json"
ME = "안나"


def lesson(n, ko, en, ru, gram, pron, vocab, sentences, dialogue, listening, questions):
    gname, gen, gru, gko, how_en, how_ru, forms, tip = gram
    rule, pen, pru, psents = pron
    title, lines = listening
    if ME not in {row[0] for row in dialogue}:
        raise SystemExit(f"unit {n} {ko}: dialogue never uses {ME}")
    if len(vocab) < 8 or len(sentences) < 6 or len(dialogue) < 4 or len(questions) < 4:
        raise SystemExit(f"unit {n} {ko}: short lesson")
    if len(forms) < 4 or len(psents) < 1 or len(lines) < 4:
        raise SystemExit(f"unit {n} {ko}: missing forms, pronunciation or listening")
    for sent, _, _ in sentences:
        if "[[" not in sent or "]]" not in sent:
            raise SystemExit(f"unit {n} {ko}: sentence missing [[grammar]]: {sent}")
    return {
        "n": n,
        "ko": ko,
        "en": en,
        "ru": ru,
        "grammar": [{
            "name": gname,
            "en": gen,
            "ru": gru,
            "ko": gko,
            "howEn": how_en,
            "howRu": how_ru,
            "forms": [{"base": base, "form": form} for base, form in forms],
            "tips": [{"ko": tip[0], "en": tip[1], "ru": tip[2]}],
        }],
        "pron": {
            "rule": rule,
            "en": pen,
            "ru": pru,
            "sentences": [{"ko": a, "en": b, "ru": c} for a, b, c in psents],
        },
        "me": ME,
        "dialogue": [{"speaker": a, "ko": b, "en": c, "ru": d} for a, b, c, d in dialogue],
        "vocab": [
            {"ko": a, "en": b, "ru": c, "ex": d, "exen": e, "exru": f}
            for a, b, c, d, e, f in vocab
        ],
        "sentences": [{"g": gname, "ko": a, "en": b, "ru": c} for a, b, c in sentences],
        "questions": [
            {"q": a, "qen": b, "qru": c, "t": d, "en": e, "ru": f, "k": list(k)}
            for a, b, c, d, e, f, k in questions
        ],
        "listening": [{"speaker": a, "ko": b, "en": c, "ru": d} for a, b, c, d in lines],
        "listeningTitle": title,
    }


def W(ko, en, ru, ex, exen, exru):
    return (ko, en, ru, ex, exen, exru)


def D(speaker, ko, en, ru):
    return (speaker, ko, en, ru)


def Q(q, qen, qru, t, en, ru, *keys):
    return (q, qen, qru, t, en, ru, keys)


# Each level is a list of lesson() results. curricula.py fills its own LEVELS.
LEVELS = {}


def main():
    import curricula

    data = json.loads(ROOT.read_text(encoding="utf-8"))
    kept = []
    for unit in data["units"]:
        if unit.get("level", 3) != 3:
            continue
        unit["level"] = 3
        kept.append(unit)
    first = next(unit for unit in kept if unit["n"] == 1)
    blob = json.dumps(first, ensure_ascii=False)
    if first.get("ko") != "대인 관계" or "샌드위치" not in blob:
        raise SystemExit("level 3 unit 1 text changed")
    if first.get("me") != "잠시드":
        raise SystemExit("level 3 speaker changed")

    generated = []
    for level in (0, 1, 2, 4, 5):
        lessons = curricula.LEVELS.get(level) or []
        if not lessons:
            raise SystemExit(f"no lessons for level {level}")
        for unit in lessons:
            stamped = dict(unit)
            stamped["level"] = level
            generated.append(stamped)

    data["units"] = kept + generated
    seen = set()
    counts = {}
    for unit in data["units"]:
        key = (unit["level"], unit["n"])
        if key in seen:
            raise SystemExit(f"duplicate unit {key}")
        seen.add(key)
        counts[unit["level"]] = counts.get(unit["level"], 0) + 1
        if not any("\uac00" <= ch <= "\ud7a3" for ch in unit["ko"]):
            raise SystemExit(f"title has no Hangul {key}")
        speakers = {row["speaker"] for row in unit["dialogue"]}
        if unit["me"] not in speakers:
            raise SystemExit(f"dialogue missing learner {key}")
        for sent in unit["sentences"]:
            if "[[" not in sent["ko"] or "]]" not in sent["ko"]:
                raise SystemExit(f"sentence missing [[ ]] {key}: {sent['ko']}")
    expected = {0: 10, 1: 12, 2: 12, 3: 16, 4: 15, 5: 16}
    if counts != expected:
        raise SystemExit(f"unexpected counts {counts}")
    if any(unit["level"] == 4 and unit["n"] == 8 for unit in data["units"]):
        raise SystemExit("level 4 must skip unit 8")
    for key in ("society", "interview", "visa"):
        if not data.get(key):
            raise SystemExit(f"missing {key}")
    ROOT.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print("wrote", ROOT, counts)


if __name__ == "__main__":
    main()

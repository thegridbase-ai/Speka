#!/usr/bin/env python3
"""
SPEKA seed validator.

Independently re-checks a produced seed JSON against the contract the iOS app
relies on. Run after build_seed.py (or standalone in CI). Exits non-zero on any
failure so it can gate commits / builds.

Checks
------
1.  File parses as valid JSON and is a non-empty array.
2.  Every entry is an object with all REQUIRED_KEYS, none empty.
3.  `id` is unique across the pool and matches "en:<slug>[:<pos>]".
4.  `level` equals the expected level (default "a1") for every entry.
5.  `pos` is in the allowed vocabulary.
6.  `phonetic` is wrapped in slashes and non-trivial.
7.  At least one translation key (tr/de/fr/es/it) is present and non-empty.
8.  `headword` has no leading/trailing whitespace and is non-empty.
9.  `exampleEN` looks like a sentence (ends with . ! or ?) — soft quality gate.

Usage
-----
    python3 scripts/validate_seed.py Speka/Resources/Seed/words_a1.json --level a1
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_KEYS = ["id", "headword", "pos", "phonetic", "exampleEN", "level"]
VALID_LEVELS = {"a1", "a2", "b1", "b2", "c1", "c2"}
VALID_POS = {
    "noun", "verb", "adjective", "adverb", "pronoun", "preposition",
    "conjunction", "determiner", "number", "interjection", "modal",
    "auxiliary",
}
TRANSLATION_KEYS = {"tr", "de", "fr", "es", "it"}

ID_RE = re.compile(r"^en:[a-z0-9-]+(?::[a-z0-9-]+)?$")
PHONETIC_RE = re.compile(r"^/.+/$")


def validate(path: Path, expected_level: str) -> tuple[int, int, list[str]]:
    """Return (count, error_count, messages)."""
    errors: list[str] = []

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return 0, 1, [f"FAIL: not valid JSON: {e}"]

    if not isinstance(data, list):
        return 0, 1, ["FAIL: top-level JSON must be an array"]
    if len(data) == 0:
        return 0, 1, ["FAIL: word pool is empty"]

    seen_ids: dict[str, int] = {}
    for idx, entry in enumerate(data):
        loc = f"entry[{idx}]"
        if not isinstance(entry, dict):
            errors.append(f"FAIL: {loc} is not an object")
            continue

        hw = entry.get("headword", "<?>")
        loc = f"entry[{idx}] ({hw!r})"

        # 2. required keys present + non-empty
        for key in REQUIRED_KEYS:
            if key not in entry:
                errors.append(f"FAIL: {loc} missing required key '{key}'")
            elif not isinstance(entry[key], str) or not entry[key].strip():
                errors.append(f"FAIL: {loc} key '{key}' is empty or not a string")

        # 3. id unique + format
        eid = entry.get("id")
        if isinstance(eid, str):
            if not ID_RE.match(eid):
                errors.append(f"FAIL: {loc} id {eid!r} does not match en:<slug>[:<pos>]")
            if eid in seen_ids:
                errors.append(
                    f"FAIL: {loc} duplicate id {eid!r} "
                    f"(first seen at entry[{seen_ids[eid]}])"
                )
            else:
                seen_ids[eid] = idx

        # 4. level
        lvl = entry.get("level")
        if lvl != expected_level:
            errors.append(f"FAIL: {loc} level {lvl!r} != expected {expected_level!r}")
        if lvl not in VALID_LEVELS:
            errors.append(f"FAIL: {loc} level {lvl!r} not a valid CEFR level")

        # 5. pos
        pos = entry.get("pos")
        if pos not in VALID_POS:
            errors.append(f"FAIL: {loc} pos {pos!r} not in allowed set")

        # 6. phonetic format
        ph = entry.get("phonetic", "")
        if isinstance(ph, str) and not PHONETIC_RE.match(ph):
            errors.append(f"FAIL: {loc} phonetic {ph!r} must be wrapped in slashes")

        # 7. at least one translation
        present = [k for k in TRANSLATION_KEYS if isinstance(entry.get(k), str) and entry[k].strip()]
        if not present:
            errors.append(f"FAIL: {loc} has no non-empty translation key (tr/de/fr/es/it)")

        # 8. headword whitespace
        if isinstance(hw, str) and hw != hw.strip():
            errors.append(f"FAIL: {loc} headword has surrounding whitespace")

        # 9. exampleEN soft sentence check
        ex = entry.get("exampleEN", "")
        if isinstance(ex, str) and ex.strip() and ex.strip()[-1] not in ".!?":
            errors.append(f"WARN: {loc} exampleEN does not end with . ! or ?")

    return len(data), sum(1 for m in errors if m.startswith("FAIL")), errors


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate a SPEKA seed JSON.")
    ap.add_argument("path", type=Path)
    ap.add_argument("--level", default="a1")
    args = ap.parse_args()

    count, fail_count, messages = validate(args.path, args.level.lower())

    print("=" * 60)
    print(f"SPEKA seed validator — {args.path}")
    print("=" * 60)
    for m in messages:
        print(m)

    warn_count = sum(1 for m in messages if m.startswith("WARN"))
    print("-" * 60)
    print(f"Entries:  {count}")
    print(f"Failures: {fail_count}")
    print(f"Warnings: {warn_count}")

    if fail_count == 0:
        print("RESULT: PASS")
        return 0
    print("RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

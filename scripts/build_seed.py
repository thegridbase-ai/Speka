#!/usr/bin/env python3
"""
SPEKA word-data pipeline — seed builder.

Reads a TAB-separated headword source file (NGSL / high-frequency basis with
SPEKA-original phonetic, example, and translation content) and emits the
bundled seed JSON the iOS app loads at first launch.

Schema (array of):
    {
      "id": "en:ability",
      "headword": "ability",
      "pos": "noun",
      "phonetic": "/əˈbɪlɪti/",
      "exampleEN": "He has the ability to learn quickly.",
      "level": "a1",
      "tr": "yetenek"
    }

Design notes
------------
* `level` is a CLI argument (default "a1") so the same pipeline builds A2..C2.
* Translations are stored under flat language keys ("tr", and later "de",
  "fr", "es", "it"). The TSV currently carries `tr` only; adding a column +
  a key in TRANSLATION_COLUMNS is the only change needed for new languages.
* `id` is "en:<headword>". When two rows share a headword but differ in part
  of speech (e.g. "work" noun vs "work" verb), the id is disambiguated as
  "en:<headword>:<pos>" so ids stay unique without breaking the common case.

Usage
-----
    python3 scripts/build_seed.py \
        --source scripts/data/a1_source.tsv \
        --out Speka/Resources/Seed/words_a1.json \
        --level a1
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

# Languages that may appear as flat keys on each entry. The first listed that
# is present (non-empty) is required; the rest are optional future phases.
# For the A1 MVP only "tr" is populated.
TRANSLATION_COLUMNS = ["tr"]  # extend with "de", "fr", "es", "it" later

VALID_LEVELS = {"a1", "a2", "b1", "b2", "c1", "c2"}

VALID_POS = {
    "noun", "verb", "adjective", "adverb", "pronoun", "preposition",
    "conjunction", "determiner", "number", "interjection", "modal",
    "auxiliary",
}

# Required keys every produced entry must carry (translation keys checked
# separately because they are language-dependent).
REQUIRED_KEYS = ["id", "headword", "pos", "phonetic", "exampleEN", "level"]


@dataclass
class SourceRow:
    headword: str
    pos: str
    phonetic: str
    example_en: str
    translations: dict[str, str] = field(default_factory=dict)
    line_no: int = 0


def _slug(headword: str) -> str:
    """Lowercase, strip accents, keep word chars — for stable id parts."""
    norm = unicodedata.normalize("NFKD", headword)
    norm = "".join(c for c in norm if not unicodedata.combining(c))
    norm = norm.lower().strip()
    norm = re.sub(r"[^a-z0-9]+", "-", norm).strip("-")
    return norm


def parse_source(path: Path) -> list[SourceRow]:
    """Parse the TAB-separated source file into SourceRows."""
    rows: list[SourceRow] = []
    text = path.read_text(encoding="utf-8")
    # Expected column order: headword, pos, phonetic, exampleEN, <tr...>
    fixed_cols = 4
    for i, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < fixed_cols + len(TRANSLATION_COLUMNS):
            raise ValueError(
                f"line {i}: expected at least "
                f"{fixed_cols + len(TRANSLATION_COLUMNS)} tab-separated "
                f"columns, got {len(parts)} -> {line!r}"
            )
        headword, pos, phonetic, example_en = (p.strip() for p in parts[:fixed_cols])
        translations: dict[str, str] = {}
        for offset, lang in enumerate(TRANSLATION_COLUMNS):
            translations[lang] = parts[fixed_cols + offset].strip()
        rows.append(
            SourceRow(
                headword=headword,
                pos=pos,
                phonetic=phonetic,
                example_en=example_en,
                translations=translations,
                line_no=i,
            )
        )
    return rows


def build_entries(rows: list[SourceRow], level: str) -> list[dict]:
    """Turn SourceRows into final schema dicts with unique, stable ids."""
    # Detect headwords that appear more than once -> need pos disambiguation.
    headword_counts = Counter(_slug(r.headword) for r in rows)
    entries: list[dict] = []
    for r in rows:
        slug = _slug(r.headword)
        if headword_counts[slug] > 1:
            entry_id = f"en:{slug}:{_slug(r.pos)}"
        else:
            entry_id = f"en:{slug}"
        entry = {
            "id": entry_id,
            "headword": r.headword,
            "pos": r.pos,
            "phonetic": r.phonetic,
            "exampleEN": r.example_en,
            "level": level,
        }
        # Flat translation keys; only include non-empty ones.
        for lang in TRANSLATION_COLUMNS:
            val = r.translations.get(lang, "").strip()
            if val:
                entry[lang] = val
        entries.append(entry)
    return entries


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the SPEKA seed JSON.")
    ap.add_argument("--source", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--level", default="a1")
    args = ap.parse_args()

    level = args.level.lower()
    if level not in VALID_LEVELS:
        print(f"ERROR: --level {level!r} not in {sorted(VALID_LEVELS)}", file=sys.stderr)
        return 2

    rows = parse_source(args.source)
    entries = build_entries(rows, level)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Built {len(entries)} entries (level={level}) -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

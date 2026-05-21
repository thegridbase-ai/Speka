# SPEKA word-data pipeline

Builds the bundled seed JSON the iOS app loads at first launch (no runtime
fetch — free + offline). American-English headwords on an NGSL / high-frequency
basis; phonetic, example, and translation content is SPEKA-original and
license-clean.

## Layout

```
scripts/
├── data/
│   └── a1_source.tsv      # canonical A1 source (headword + original content)
├── build_seed.py          # source TSV -> seed JSON (assigns ids, level)
├── validate_seed.py       # independent contract check (CI / commit gate)
└── README.md
```

Output: `Speka/Resources/Seed/words_a1.json`

## Build + validate

```bash
python3 scripts/build_seed.py \
  --source scripts/data/a1_source.tsv \
  --out Speka/Resources/Seed/words_a1.json \
  --level a1

python3 scripts/validate_seed.py Speka/Resources/Seed/words_a1.json --level a1
```

Both are zero-dependency (Python 3 stdlib only). The validator exits non-zero
on any failure.

## Schema (per entry)

```json
{ "id": "en:ability", "headword": "ability", "pos": "noun",
  "phonetic": "/əˈbɪlɪti/", "exampleEN": "He has the ability to learn quickly.",
  "level": "a1", "tr": "yetenek" }
```

`id` is `en:<slug>`; if two rows share a headword but differ in part of speech
(e.g. `work` noun vs verb) the id is disambiguated as `en:<slug>:<pos>`.

## Extending

* **More A1 words** — add rows to `a1_source.tsv` (toward the ~500 A1 target),
  rebuild, revalidate.
* **More levels** — add `a2_source.tsv` etc. and run with `--level a2`
  (`--out Speka/Resources/Seed/words_a2.json`). All CEFR levels a1–c2 accepted.
* **More base languages** (de/fr/es/it) — append a column to the TSV and add the
  key to `TRANSLATION_COLUMNS` in `build_seed.py`. Entries gain flat keys
  (`"de": ...`) alongside `tr`; the validator already accepts tr/de/fr/es/it.
```

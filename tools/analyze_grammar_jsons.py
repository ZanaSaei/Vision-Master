# -*- coding: utf-8 -*-
"""Analyze ALL grammar-related JSON files in the Vision Master project.

Inventories every question-bearing structure, its type, the language of its
text fields, and flags mixed Farsi/English strings that could render badly
in an RTL (right-to-left) label.

Writes a UTF-8 report to tools/grammar_analysis_report.txt
"""
import json
import os
import re
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

AR_FA = re.compile(r"[\u0600-\u06FF]")          # Arabic/Farsi letters
LATIN = re.compile(r"[A-Za-z]")

def has_fa(s):
    return bool(AR_FA.search(s))

def has_latin(s):
    return bool(LATIN.search(s))

report = []

def log(*a):
    line = " ".join(str(x) for x in a)
    report.append(line)

stats = {}

def note_stat(kind, field, lang):
    k = (kind, field)
    stats.setdefault(k, {"fa": 0, "en": 0, "mixed": 0, "other": 0})
    stats[k][lang] += 1

mixed_examples = []

def check_text(s, kind, field, path, item_id=""):
    if not isinstance(s, str) or not s.strip():
        return
    if has_fa(s) and has_latin(s):
        mixed_examples.append((path, item_id, kind, field, s.strip()[:220]))
        stats.setdefault((kind, field), {"fa": 0, "en": 0, "mixed": 0, "other": 0})
        stats[(kind, field)]["mixed"] += 1
    elif has_fa(s):
        note_stat(kind, field, "fa")
    elif has_latin(s):
        note_stat(kind, field, "en")
    else:
        note_stat(kind, field, "other")

def walk(obj, path, kind_ctx=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, str):
                check_text(v, kind_ctx or str(obj.get("type", "?")), k, path, str(obj.get("id", "")))
            else:
                walk(v, path, str(obj.get("type", "")) if k == "type" else kind_ctx)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, path, kind_ctx)

files = sorted(glob.glob(os.path.join(DATA, "**", "*.json"), recursive=True))
log("=== GRAMMAR JSON INVENTORY ===")
for f in files:
    rel = os.path.relpath(f, ROOT)
    size = os.path.getsize(f)
    try:
        with open(f, "r", encoding="utf-8") as fh:
            json.load(fh)
    except Exception as e:
        log(f"{rel}: PARSE ERROR {e}")
        continue
    log(f"{rel} ({size//1024} KB)")

log("")
log("=== STRING FIELD LANGUAGE STATS (kind/field -> count by lang) ===")

for f in files:
    rel = os.path.relpath(f, ROOT)
    try:
        with open(f, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception:
        continue
    log(f"--- {rel}")
    before = {k: dict(v) for k, v in stats.items()}
    walk(data, rel)
    for (kind, field), langs in stats.items():
        old = before.get((kind, field), {"fa": 0, "en": 0, "mixed": 0, "other": 0})
        d = {l: langs[l] - old[l] for l in ("fa", "en", "mixed", "other")}
        if any(d.values()):
            log(f"   {kind:18s} {field:22s} fa={d['fa']:4d} en={d['en']:4d} mixed={d['mixed']:4d} other={d['other']:3d}")

log("")
log(f"=== MIXED FA/EN STRINGS ({len(mixed_examples)}) ===")
for path, item_id, kind, field, s in mixed_examples:
    log(f"[{path}] id={item_id} kind={kind} field={field}")
    log(f"    {s}")

with open(os.path.join(ROOT, "tools", "grammar_analysis_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(report))
print("report written:", len(report), "lines,", len(mixed_examples), "mixed strings")

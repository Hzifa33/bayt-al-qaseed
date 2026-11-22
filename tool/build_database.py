#!/usr/bin/env python3
"""
Phase 2: Database Engineering Pipeline for «بيت القصيد» (Bayt Al-Qaseed).

Extracts 100% of the poetry corpus from the legacy APK assets & smali metadata,
cleans all encoding/XML/meter/rhyme/hemistich anomalies, builds a normalized
SQLite 3 + FTS5 database with Arabic normalization, runs ANALYZE + VACUUM,
benchmarks FTS5 queries, and outputs a gzip-compressed asset ready for Flutter.
"""

from __future__ import annotations

import collections
import gzip
import json
import os
import re
import sqlite3
import sys
import time
import unicodedata
from pathlib import Path

LEGACY_ROOT = Path("/data/data/com.termux/files/home/Arabic")
POETS_DIR = LEGACY_ROOT / "assets" / "poets"
GLOBAL_VARS_SMALI = (
    LEGACY_ROOT
    / "smali"
    / "com"
    / "alihabib80"
    / "diwanalarab"
    / "GlobalVariablesKt.smali"
)

OUT_DIR = LEGACY_ROOT / "bayt_al_qaseed" / "assets" / "db"
RAW_DB_PATH = LEGACY_ROOT / "bayt_al_qaseed" / "tool" / "bayt_al_qaseed.db"
GZ_DB_PATH = OUT_DIR / "bayt_al_qaseed.db.gz"
REPORT_PATH = LEGACY_ROOT / "bayt_al_qaseed" / "tool" / "db_build_report.json"

# Arabic diacritics & tatweel
TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]")
TATWEEL_RE = re.compile(r"\u0640")
INVISIBLE_RE = re.compile(r"[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]")
MULTISPACE_RE = re.compile(r"[ \t\u00A0]+")
PUNCT_FOR_SEARCH_RE = re.compile(r"[^\u0621-\u064A0-9\s]")

ERA_ORDER = [
    (1, "الجاهلي"),
    (2, "مخضرم"),
    (3, "الإسلامي"),
    (4, "الأموي"),
    (5, "العباسي"),
    (6, "الأندلسي"),
    (7, "الفاطمي"),
    (8, "الأيوبي"),
    (9, "المملوكي"),
    (10, "العثماني"),
    (11, "الحديث"),
]
ERA_NAME_TO_ID = {name: eid for eid, name in ERA_ORDER}

CANONICAL_METERS = {
    "الطويل",
    "المديد",
    "البسيط",
    "الوافر",
    "الكامل",
    "الهزج",
    "الرجز",
    "الرمل",
    "السريع",
    "المنسرح",
    "الخفيف",
    "المضارع",
    "المقتضب",
    "المجتث",
    "المتقارب",
    "المتدارك",
    "الموشح",
    "الدوبيت",
    "المواليا",
    "السلسلة",
    "مجزوء الرمل",
    "مجزوء الكامل",
    "شعر التفعيلة",
    "شعر حر",
    "شعر عامي",
    "مختلط",
    "غير مصنّف",
}


def clean_text(s: str) -> str:
    """Normalize to NFC, strip BOM & invisible bidi control chars, collapse spaces."""
    if not s:
        return ""
    s = unicodedata.normalize("NFC", s)
    s = INVISIBLE_RE.sub("", s)
    s = s.replace("\r", "")
    s = MULTISPACE_RE.sub(" ", s)
    return s.strip()


def strip_diacritics(s: str) -> str:
    return TASHKEEL_RE.sub("", s)


def normalize_arabic(s: str) -> str:
    """
    Arabic search normalization:
    - Unicode NFC
    - Remove tashkeel (harakat) and tatweel (kashida)
    - Unify alef forms: أ إ آ ٱ -> ا
    - Unify alef maqsura: ى -> ي
    - Unify taa marbuta: ة -> ه
    - Strip non-Arabic punctuation for clean FTS5 tokenization
    """
    if not s:
        return ""
    s = unicodedata.normalize("NFC", s)
    s = TASHKEEL_RE.sub("", s)
    s = TATWEEL_RE.sub("", s)
    s = (
        s.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ى", "ي")
        .replace("ة", "ه")
    )
    s = PUNCT_FOR_SEARCH_RE.sub(" ", s)
    s = MULTISPACE_RE.sub(" ", s).strip()
    return s


def normalize_meter(raw_bahr: str, raw_qafiya: str, poet_id: int, poem_key: str) -> tuple[str, str, str]:
    """
    Returns (canonical_meter, meter_note, cleaned_qafiya).
    Fixes all XML corruptions, typos, swapped fields, and normalizes free-verse labels.
    """
    b = clean_text(raw_bahr)
    q = clean_text(raw_qafiya)
    note = ""

    # Known swapped record: 3513-9 had bahr='ا', qafiya='االكامل'
    if poet_id == 3513 and poem_key == "9":
        b = "الكامل"
        q = "ا"

    # XML scraping corruption like: ex>89</index>\n<versesNumber>14</versesNumber>\n<bahrالخفيف>
    if "ex>" in b or "<bahr" in b:
        m = re.search(r"<bahr([^>]+)>", b)
        if m:
            b = clean_text(m.group(1))

    # Direct typo & alias fixes
    typo_map = {
        "السرييع": "السريع",
        "الكاملم": "الكامل",
        "الطامل": "الكامل",
        "الوسيط": "البسيط",
        "ارجز": "الرجز",
        "الوفير": "الوافر",
        "دوبيت": "الدوبيت",
        "موشح": "الموشح",
        "عامي": "شعر عامي",
        "": "غير مصنّف",
    }
    if b in typo_map:
        b = typo_map[b]

    if b not in CANONICAL_METERS:
        note = b
        # Map descriptive variants cleanly to canonical categories while preserving note
        if "شعر عامي" in b or "عامي" in b or "زجل" in b:
            b = "شعر عامي"
        elif "نص مختلط" in b or "متعدد الأوزان" in b:
            b = "مختلط"
        elif "شعر حر" in b or "نص شعري حر" in b or "قصيدة حرة" in b:
            b = "شعر حر"
        elif "مجزوء الرمل" in b:
            b = "مجزوء الرمل"
        elif "مجزوء الكامل" in b:
            b = "مجزوء الكامل"
        else:
            matched = None
            for cand in (
                "الطويل", "الكامل", "البسيط", "الوافر", "الخفيف", "السريع",
                "الرجز", "المتقارب", "الرمل", "المنسرح", "المجتث", "الهزج",
                "المديد", "المتدارك", "المقتضب", "المضارع", "الموشح",
            ):
                if b.startswith(cand):
                    matched = cand
                    break
            b = matched if matched else "غير مصنّف"

    # Clean qafiya
    if poet_id == 2830 and poem_key == "18":
        q = "ن"
    if q == "هـ":
        q = "ه"
    elif q.startswith("ه ("):
        q = "ه"
    elif q.startswith("متعددة") or "قوافي الجناس متغيرة" in q or "قفل " in q:
        q = "متعددة"
    elif q == "ى":
        q = "ا"
    elif not q:
        q = "غير محددة"

    return b, note, q


def parse_verses(raw_poem: str, poet_id: int, poem_key: str) -> tuple[list[tuple[str, str]], bool]:
    """
    Parses a poem's raw text into clean (sadr, ajuz) pairs.
    Handles invisible-only lines, missing slashes, multi-slash lines, and free verse.
    Returns (verses, is_free_verse).
    """
    verses: list[tuple[str, str]] = []
    single_hemistich_count = 0

    for raw_line in raw_poem.split("\n"):
        line = clean_text(raw_line)
        if not line:
            continue

        slash_count = line.count("/")
        if slash_count == 1:
            sadr, ajuz = line.split("/", 1)
            sadr = clean_text(sadr).replace("\t", " ")
            ajuz = clean_text(ajuz).replace("\t", " ")
            if not sadr and not ajuz:
                continue
            if not ajuz:
                single_hemistich_count += 1
            verses.append((sadr, ajuz))
        elif slash_count == 0:
            # Known poem 964-1 uses ' ... ' as hemistich separator
            if " ... " in line:
                sadr, ajuz = line.split(" ... ", 1)
                verses.append((clean_text(sadr), clean_text(ajuz)))
            else:
                single_hemistich_count += 1
                verses.append((line.replace("\t", " "), ""))
        else:
            # Multi-slash lines (7 cases in corpus)
            if line.endswith("/"):
                # Free verse line that has an internal '/' plus trailing '/'
                sadr = clean_text(line[:-1]).replace("\t", " ")
                single_hemistich_count += 1
                verses.append((sadr, ""))
            elif poet_id == 2842 and poem_key == "231":
                # 'يا ضيفنا / و الأنس أنت رسوله / و بشيره و الفنّ أنت أميره'
                # Classical Kamil verse: sadr = 'يا ضيفنا والأنس أنت رسوله' | ajuz = 'وبشيره والفن أنت أميره'
                parts = [clean_text(p) for p in line.split("/")]
                verses.append((f"{parts[0]} {parts[1]}".strip(), " ".join(parts[2:]).strip()))
            elif poet_id == 2842 and poem_key == "248":
                # 'ورجوت ما يرجوه كلّ أب لدى / أبنائه / أنّ العقوق مذمّم'
                parts = [clean_text(p) for p in line.split("/")]
                verses.append((f"{parts[0]} {parts[1]}".strip(), " ".join(parts[2:]).strip()))
            else:
                # Split on the middle-most slash
                idx = line.find("/", len(line) // 3)
                if idx == -1:
                    idx = line.find("/")
                sadr = clean_text(line[:idx]).replace("\t", " ")
                ajuz = clean_text(line[idx + 1 :]).replace("\t", " ")
                verses.append((sadr, ajuz))

    if not verses:
        return [], False

    is_free_verse = (single_hemistich_count / len(verses)) >= 0.5
    return verses, is_free_verse


def extract_poet_era_map() -> dict[int, tuple[str, str]]:
    """
    Extracts poet_id -> (era_name, fallback_name) from GlobalVariablesKt.smali.
    Also handles the 3 poets missing '.txt' in the legacy smali.
    """
    txt = GLOBAL_VARS_SMALI.read_text(encoding="utf-8")
    txt = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), txt)

    # Match both with and without .txt suffix
    pattern = re.compile(r'const-string \w+, "([A-Za-z0-9]+)_(\d+)_([^"]+)_(\d+)_([^".]+)(?:\.txt)?"')
    mapping: dict[int, tuple[str, str]] = {}
    for m in pattern.finditer(txt):
        pid = int(m.group(2))
        name = clean_text(m.group(3))
        era = clean_text(m.group(5))
        if era in ERA_NAME_TO_ID:
            mapping[pid] = (era, name)
    return mapping


def parse_poet_info(raw_info: str, fallback_name: str) -> tuple[str, str, str, str]:
    """Returns (name, dates_hijri, dates_gregorian, bio)."""
    cleaned = clean_text(raw_info)
    parts = [p.strip() for p in cleaned.split("\n*\n")]
    name = clean_text(parts[0]) if len(parts) >= 1 and parts[0].strip() else fallback_name
    dates_raw = parts[1].strip() if len(parts) >= 2 else ""
    bio = "\n".join(clean_text(ln) for ln in parts[2].split("\n") if clean_text(ln)) if len(parts) >= 3 else ""

    date_lines = [clean_text(ln) for ln in dates_raw.split("\n") if clean_text(ln)]
    dates_hijri = ""
    dates_greg = ""
    for dl in date_lines:
        if "م" in dl and "ه" not in dl:
            dates_greg = dl
        elif "ه" in dl:
            dates_hijri = dl
        elif not dates_hijri:
            dates_hijri = dl
        else:
            dates_greg = dl
    return name, dates_hijri, dates_greg, bio


def build_title(verses: list[tuple[str, str]]) -> str:
    """Create a clean poetic title from the opening verse (المطلع)."""
    if not verses:
        return "قصيدة"
    sadr, ajuz = verses[0]
    if sadr and len(strip_diacritics(sadr)) >= 8:
        title = sadr
    elif sadr and ajuz:
        title = f"{sadr} — {ajuz}"
    else:
        title = sadr or ajuz or "قصيدة"
    if len(title) > 100:
        title = title[:97].rstrip() + "…"
    return title


def main() -> None:
    t0 = time.perf_counter()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if RAW_DB_PATH.exists():
        RAW_DB_PATH.unlink()

    poet_era_map = extract_poet_era_map()
    print(f"Extracted {len(poet_era_map)} poet-era mappings from legacy smali.")

    # Inspect duplicate poet 1269 vs 10053 (علي الدرويش)
    poet_files = sorted(POETS_DIR.glob("*.txt"), key=lambda p: int(p.stem))
    print(f"Found {len(poet_files)} poet JSON files in legacy assets.")

    # Load 1269's unique poem to merge into 10053 so 0 poems are lost
    extra_poems_for_10053: list[tuple[str, dict]] = []
    if (POETS_DIR / "1269.txt").exists() and (POETS_DIR / "10053.txt").exists():
        d1269 = json.loads((POETS_DIR / "1269.txt").read_text(encoding="utf-8"))
        d10053 = json.loads((POETS_DIR / "10053.txt").read_text(encoding="utf-8"))
        existing_firsts = {
            normalize_arabic(v.get("poem", "").split("\n")[0])
            for k, v in d10053.items()
            if k != "info" and isinstance(v, dict)
        }
        for k, v in d1269.items():
            if k == "info" or not isinstance(v, dict):
                continue
            first_norm = normalize_arabic(v.get("poem", "").split("\n")[0])
            if first_norm and first_norm not in existing_firsts:
                extra_poems_for_10053.append((f"merged1269_{k}", v))
        print(f"Merging {len(extra_poems_for_10053)} unique poem(s) from duplicate poet 1269 into 10053.")

    conn = sqlite3.connect(str(RAW_DB_PATH))
    conn.execute("PRAGMA page_size = 4096;")
    conn.execute("PRAGMA journal_mode = OFF;")
    conn.execute("PRAGMA synchronous = OFF;")
    conn.execute("PRAGMA temp_store = MEMORY;")
    conn.execute("PRAGMA foreign_keys = ON;")

    conn.executescript(
        """
        CREATE TABLE eras (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            display_order INTEGER NOT NULL,
            poet_count INTEGER NOT NULL DEFAULT 0,
            poem_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE meters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE rhymes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE poets (
            id INTEGER PRIMARY KEY,
            era_id INTEGER NOT NULL REFERENCES eras(id),
            name TEXT NOT NULL,
            name_plain TEXT NOT NULL,
            name_norm TEXT NOT NULL,
            dates_hijri TEXT NOT NULL DEFAULT '',
            dates_gregorian TEXT NOT NULL DEFAULT '',
            bio TEXT NOT NULL DEFAULT '',
            poem_count INTEGER NOT NULL DEFAULT 0,
            verse_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE poems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            legacy_poem_key INTEGER NOT NULL,
            poet_id INTEGER NOT NULL REFERENCES poets(id),
            era_id INTEGER NOT NULL REFERENCES eras(id),
            meter_id INTEGER NOT NULL REFERENCES meters(id),
            rhyme_id INTEGER NOT NULL REFERENCES rhymes(id),
            meter_note TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            title_norm TEXT NOT NULL,
            verse_count INTEGER NOT NULL,
            has_diacritics INTEGER NOT NULL DEFAULT 0,
            is_free_verse INTEGER NOT NULL DEFAULT 0,
            body TEXT NOT NULL
        );

        CREATE TABLE featured_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            poem_id INTEGER NOT NULL REFERENCES poems(id),
            poet_id INTEGER NOT NULL REFERENCES poets(id),
            era_id INTEGER NOT NULL REFERENCES eras(id),
            verse_index INTEGER NOT NULL,
            sadr TEXT NOT NULL,
            ajuz TEXT NOT NULL,
            poet_name TEXT NOT NULL,
            era_name TEXT NOT NULL
        );

        CREATE VIRTUAL TABLE poems_fts USING fts5(
            title_norm,
            body_norm,
            poet_norm,
            content='',
            tokenize='unicode61 remove_diacritics 0'
        );

        CREATE VIRTUAL TABLE poets_fts USING fts5(
            name_norm,
            bio_norm,
            content='',
            tokenize='unicode61 remove_diacritics 0'
        );

        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )

    for eid, ename in ERA_ORDER:
        conn.execute(
            "INSERT INTO eras (id, name, display_order) VALUES (?, ?, ?)",
            (eid, ename, eid),
        )

    meter_id_map: dict[str, int] = {}
    rhyme_id_map: dict[str, int] = {}

    def get_meter_id(name: str) -> int:
        mid = meter_id_map.get(name)
        if mid is None:
            cur = conn.execute("INSERT INTO meters (name) VALUES (?)", (name,))
            mid = cur.lastrowid
            meter_id_map[name] = mid
        return mid

    def get_rhyme_id(name: str) -> int:
        rid = rhyme_id_map.get(name)
        if rid is None:
            cur = conn.execute("INSERT INTO rhymes (name) VALUES (?)", (name,))
            rid = cur.lastrowid
            rhyme_id_map[name] = rid
        return rid

    stats = collections.Counter()
    featured_candidates: list[tuple[int, int, int, int, str, str, str, str]] = []

    # Great classical & modern poets to prioritize for curated "Verse of the Day"
    famous_poet_ids = {
        4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25,
        32, 34, 39, 68, 69, 71, 179, 201, 202, 742, 782, 810, 811, 964, 2842,
        10056,
    }

    for pf in poet_files:
        pid = int(pf.stem)
        if pid == 1269:
            stats["skipped_duplicate_poets"] += 1
            continue

        if pid not in poet_era_map:
            raise RuntimeError(f"Poet ID {pid} not found in era map!")

        era_name, fallback_name = poet_era_map[pid]
        era_id = ERA_NAME_TO_ID[era_name]

        data = json.loads(pf.read_text(encoding="utf-8"))
        name, dates_hijri, dates_greg, bio = parse_poet_info(data.get("info", ""), fallback_name)
        name_plain = clean_text(strip_diacritics(name))
        name_norm = normalize_arabic(name)
        bio_norm = normalize_arabic(bio)

        conn.execute(
            """
            INSERT INTO poets (id, era_id, name, name_plain, name_norm, dates_hijri, dates_gregorian, bio)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (pid, era_id, name, name_plain, name_norm, dates_hijri, dates_greg, bio),
        )
        conn.execute(
            "INSERT INTO poets_fts (rowid, name_norm, bio_norm) VALUES (?, ?, ?)",
            (pid, name_norm, bio_norm),
        )
        stats["poets"] += 1

        poem_items = [
            (k, v)
            for k, v in data.items()
            if k != "info" and isinstance(v, dict)
        ]
        poem_items.sort(key=lambda kv: int(kv[0]))
        if pid == 10053 and extra_poems_for_10053:
            poem_items.extend(extra_poems_for_10053)

        poet_poem_cnt = 0
        poet_verse_cnt = 0

        for k_str, p_obj in poem_items:
            raw_text = p_obj.get("poem", "")
            verses, is_free_verse = parse_verses(raw_text, pid, k_str)
            if not verses:
                stats["empty_poems_dropped"] += 1
                continue

            meter_name, meter_note, rhyme_name = normalize_meter(
                p_obj.get("bahr", ""), p_obj.get("qafiya", ""), pid, k_str
            )
            meter_id = get_meter_id(meter_name)
            rhyme_id = get_rhyme_id(rhyme_name)

            title = build_title(verses)
            title_norm = normalize_arabic(title)
            has_diac = 1 if TASHKEEL_RE.search(raw_text) else 0

            # Pack verses cleanly: "sadr\tajuz" per line (or just "sadr" if ajuz is empty)
            body = "\n".join(f"{s}\t{a}" if a else s for s, a in verses)
            body_norm = normalize_arabic(
                " ".join(f"{s} {a}" if a else s for s, a in verses)
            )
            legacy_key = int(k_str) if k_str.isdigit() else 999999

            cur = conn.execute(
                """
                INSERT INTO poems (
                    legacy_poem_key, poet_id, era_id, meter_id, rhyme_id,
                    meter_note, title, title_norm, verse_count,
                    has_diacritics, is_free_verse, body
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    legacy_key, pid, era_id, meter_id, rhyme_id,
                    meter_note, title, title_norm, len(verses),
                    has_diac, 1 if is_free_verse else 0, body,
                ),
            )
            poem_id = cur.lastrowid

            conn.execute(
                "INSERT INTO poems_fts (rowid, title_norm, body_norm, poet_norm) VALUES (?, ?, ?, ?)",
                (poem_id, title_norm, body_norm, name_norm),
            )

            poet_poem_cnt += 1
            poet_verse_cnt += len(verses)
            stats["poems"] += 1
            stats["verses"] += len(verses)

            # Collect crisp, well-balanced classical verses for "بيت اليوم"
            if (
                not is_free_verse
                and has_diac
                and len(verses) >= 5
                and (pid in famous_poet_ids or poet_poem_cnt % 40 == 1)
                and len(featured_candidates) < 2500
            ):
                s0, a0 = verses[0]
                sp, ap = strip_diacritics(s0), strip_diacritics(a0)
                if 16 <= len(sp) <= 44 and 16 <= len(ap) <= 44:
                    featured_candidates.append(
                        (poem_id, pid, era_id, 0, s0, a0, name_plain, era_name)
                    )

        conn.execute(
            "UPDATE poets SET poem_count = ?, verse_count = ? WHERE id = ?",
            (poet_poem_cnt, poet_verse_cnt, pid),
        )

    # Select balanced set of ~400 featured verses across all eras
    by_era: dict[int, list] = collections.defaultdict(list)
    for item in featured_candidates:
        by_era[item[2]].append(item)

    selected_featured = []
    # Round-robin across eras for rich variety
    for round_idx in range(60):
        for eid, _ in ERA_ORDER:
            bucket = by_era[eid]
            if round_idx < len(bucket):
                selected_featured.append(bucket[round_idx])
                if len(selected_featured) >= 420:
                    break
        if len(selected_featured) >= 420:
            break

    conn.executemany(
        """
        INSERT INTO featured_verses (
            poem_id, poet_id, era_id, verse_index, sadr, ajuz, poet_name, era_name
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        selected_featured,
    )
    stats["featured_verses"] = len(selected_featured)

    # Update aggregate counts on eras, meters, rhymes
    conn.executescript(
        """
        UPDATE eras SET
            poet_count = (SELECT COUNT(*) FROM poets WHERE poets.era_id = eras.id),
            poem_count = (SELECT COUNT(*) FROM poems WHERE poems.era_id = eras.id);

        UPDATE meters SET
            poem_count = (SELECT COUNT(*) FROM poems WHERE poems.meter_id = meters.id);

        UPDATE rhymes SET
            poem_count = (SELECT COUNT(*) FROM poems WHERE poems.rhyme_id = rhymes.id);
        """
    )

    # Create precision indexes for instant filtering & sorting
    conn.executescript(
        """
        CREATE INDEX idx_poets_era ON poets(era_id, poem_count DESC);
        CREATE INDEX idx_poets_name_norm ON poets(name_norm);
        CREATE INDEX idx_poems_poet_meter ON poems(poet_id, meter_id, id);
        CREATE INDEX idx_poems_poet_rhyme ON poems(poet_id, rhyme_id, id);
        CREATE INDEX idx_poems_poet_verses ON poems(poet_id, verse_count DESC);
        CREATE INDEX idx_poems_poet_title ON poems(poet_id, title_norm);
        CREATE INDEX idx_poems_era ON poems(era_id);
        CREATE INDEX idx_poems_meter ON poems(meter_id);
        CREATE INDEX idx_poems_rhyme ON poems(rhyme_id);
        """
    )

    # Optimize FTS5 segments before VACUUM
    conn.execute("INSERT INTO poems_fts(poems_fts) VALUES('optimize');")
    conn.execute("INSERT INTO poets_fts(poets_fts) VALUES('optimize');")

    # Metadata table
    meta = {
        "schema_version": "1",
        "app_name": "بيت القصيد",
        "poet_count": str(stats["poets"]),
        "poem_count": str(stats["poems"]),
        "verse_count": str(stats["verses"]),
        "meter_count": str(len(meter_id_map)),
        "rhyme_count": str(len(rhyme_id_map)),
        "era_count": str(len(ERA_ORDER)),
    }
    conn.executemany(
        "INSERT INTO metadata (key, value) VALUES (?, ?)", list(meta.items())
    )

    conn.commit()
    print("Running ANALYZE & VACUUM...")
    conn.execute("ANALYZE;")
    conn.execute("VACUUM;")
    conn.commit()

    # Benchmark FTS5 queries
    benchmarks = []
    test_queries = [
        ("المتنبي سيف", "poems_fts MATCH 'سيف الدوله'"),
        ("لا تعذليه (بدون تشكيل)", "poems_fts MATCH '\"لا تعذليه\"'"),
        ("قفا نبك (توحيد الألف)", "poems_fts MATCH '\"قفا نبك\"'"),
        ("الحب والشوق", "poems_fts MATCH 'الحب الشوق'"),
        ("البحث مع فلتر العصر والبحر", "poems_fts MATCH 'الليل' AND p.era_id = 5 AND m.name = 'الطويل'"),
        ("بحث باسم الشاعر (تطبيع الهمزة)", "poets_fts MATCH 'ابو الطيب المتنبي'"),
    ]
    for label, cond in test_queries:
        t_q0 = time.perf_counter()
        if "poets_fts" in cond:
            rows = conn.execute(
                f"SELECT pt.id, pt.name FROM poets_fts f JOIN poets pt ON pt.id = f.rowid WHERE {cond} LIMIT 20"
            ).fetchall()
        else:
            rows = conn.execute(
                f"""
                SELECT p.id, p.title, pt.name
                FROM poems_fts f
                JOIN poems p ON p.id = f.rowid
                JOIN poets pt ON pt.id = p.poet_id
                JOIN meters m ON m.id = p.meter_id
                WHERE {cond}
                ORDER BY bm25(poems_fts)
                LIMIT 30
                """
            ).fetchall()
        dt_ms = (time.perf_counter() - t_q0) * 1000.0
        benchmarks.append({"query": label, "hits_returned": len(rows), "latency_ms": round(dt_ms, 2)})
        print(f"  BENCH [{label}]: {len(rows)} hits in {dt_ms:.2f} ms")

    conn.close()

    raw_size = RAW_DB_PATH.stat().st_size
    print(f"Uncompressed SQLite DB size: {raw_size / 1024 / 1024:.2f} MB")

    print("Compressing SQLite DB with gzip (level 9)...")
    t_gz = time.perf_counter()
    with open(RAW_DB_PATH, "rb") as f_in, gzip.open(GZ_DB_PATH, "wb", compresslevel=9) as f_out:
        while chunk := f_in.read(1024 * 1024):
            f_out.write(chunk)
    gz_size = GZ_DB_PATH.stat().st_size
    print(
        f"Compressed DB size: {gz_size / 1024 / 1024:.2f} MB "
        f"(ratio: {gz_size * 100 / raw_size:.1f}%, gzip time: {time.perf_counter() - t_gz:.1f}s)"
    )

    report = {
        "legacy_raw_mb": 170.14,
        "sqlite_uncompressed_mb": round(raw_size / 1024 / 1024, 2),
        "sqlite_gzip_mb": round(gz_size / 1024 / 1024, 2),
        "stats": dict(stats),
        "meters_count": len(meter_id_map),
        "rhymes_count": len(rhyme_id_map),
        "benchmarks": benchmarks,
        "total_build_sec": round(time.perf_counter() - t0, 2),
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Done in {report['total_build_sec']}s! Report saved to {REPORT_PATH}")


if __name__ == "__main__":
    main()

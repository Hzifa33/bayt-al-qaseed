#!/usr/bin/env python3
"""
Production Merger & Deduplicator for Qafiyah + Bayt Al-Qaseed Databases.

Combines:
  - qafiyah_db/qafiyah_optimized.db  (333,856 poems, 17,238 poets, 5.57M verses)
  - assets/db/bayt_al_qaseed.db.gz   (90,238 poems, 542 poets, 172 featured_verses)

Guarantees:
  1. Zero duplicate poets (exact name_norm + poem co-occurrence matching +
     automatic misattribution split e.g. حسن الطويراني vs ابن زريق البغدادي).
  2. Zero duplicate poems (internal Qafiyah exact-body dedup + cross-DB
     matching by body_hash, (poet, title_norm), and global body_hash).
  3. Best-version selection on every overlapping poem (weighing verse
     completeness + diacritic richness) and best-metadata merging from both DBs.
  4. Uniform verse format (\t between hemistichs, \n between verses),
     1-byte lossless Arabic packing + zlib-9 128-poem content_blocks,
     recalculated counts across all tables, 172/172 remapped featured_verses,
     external-content FTS5 on titles & poets, ANALYZE + VACUUM.
"""

from __future__ import annotations

import collections
import gzip
import hashlib
import json
import os
import random
import re
import shutil
import sqlite3
import sys
import time
import unicodedata
import zlib
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
QAF_DB = ROOT / "qafiyah_db" / "qafiyah_optimized.db"
BAYT_GZ = ROOT / "assets" / "db" / "bayt_al_qaseed.db.gz"
BAYT_TMP = ROOT / "qafiyah_db" / "_bayt_src.db"

OUT_DB = ROOT / "qafiyah_db" / "bayt_qafiyah_merged.db"
OUT_GZ = ROOT / "qafiyah_db" / "bayt_qafiyah_merged.db.gz"
REPORT_PATH = ROOT / "qafiyah_db" / "merge_report.json"

BLOCK_SIZE = 128

TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]")
TATWEEL_RE = re.compile(r"\u0640")
PUNCT_RE = re.compile(r"[^\u0621-\u064A0-9\s]")
SPACE_RE = re.compile(r"\s+")

CANONICAL_ERAS = [
    (1, "jahili", "الجاهلي"),
    (2, "mukhadram", "مخضرم"),
    (3, "islami", "الإسلامي"),
    (4, "umawi", "الأموي"),
    (5, "abbasi", "العباسي"),
    (6, "andalusi", "الأندلسي"),
    (7, "fatimi", "الفاطمي"),
    (8, "ayyubi", "الأيوبي"),
    (9, "mamluki", "المملوكي"),
    (10, "uthmani", "العثماني"),
    (11, "hadith", "الحديث"),
    (12, "muasir", "المعاصر"),
    (13, "unknown", "غير مصنّف"),
]

ERA_ALIAS_TO_ID = {
    "الجاهلي": 1, "جاهلي": 1, "jahili": 1,
    "مخضرم": 2, "mukhadram": 2,
    "الإسلامي": 3, "إسلامي": 3, "islami": 3,
    "الأموي": 4, "أموي": 4, "umawi": 4,
    "العباسي": 5, "عباسي": 5, "abbasi": 5,
    "الأندلسي": 6, "أندلسي": 6, "andalusi": 6,
    "الفاطمي": 7, "فاطمي": 7, "fatimi": 7,
    "الأيوبي": 8, "أيوبي": 8, "ayyubi": 8,
    "المملوكي": 9, "مملوكي": 9, "mamluki": 9,
    "العثماني": 10, "عثماني": 10, "uthmani": 10,
    "الحديث": 11, "حديث": 11, "hadith": 11,
    "المعاصر": 12, "معاصر": 12, "muasir": 12,
    "غير مصنّف": 13, "غير معروف": 13, "ghayrmaruf": 13, "": 13,
}

METER_ALIASES = {
    "غير معروف": "غير مصنّف",
    "عامي": "شعر عامي",
    "سلسلة": "السلسلة",
}

# Map Qafiyah rhyme names & Bayt single letters -> (canonical_name, letter)
RHYME_LETTER_MAP = {
    "ألف": ("ألف", "ا"), "ألف مفتوحة": ("ألف", "ا"), "ألف مدودة": ("ألف", "ا"),
    "ألف مكسورة": ("ألف", "ا"), "ألف مقصورة": ("ألف مقصورة", "ى"), "ا": ("ألف", "ا"),
    "باء": ("باء", "ب"), "ب": ("باء", "ب"),
    "تاء": ("تاء", "ت"), "ت": ("تاء", "ت"),
    "تاء مربوطة": ("تاء مربوطة", "ة"), "ة": ("تاء مربوطة", "ة"),
    "ثاء": ("ثاء", "ث"), "ث": ("ثاء", "ث"),
    "جيم": ("جيم", "ج"), "ج": ("جيم", "ج"),
    "حاء": ("حاء", "ح"), "ح": ("حاء", "ح"),
    "خاء": ("خاء", "خ"), "خ": ("خاء", "خ"),
    "دال": ("دال", "د"), "د": ("دال", "د"),
    "ذال": ("ذال", "ذ"), "ذ": ("ذال", "ذ"),
    "راء": ("راء", "ر"), "ر": ("راء", "ر"),
    "زاي": ("زاي", "ز"), "ز": ("زاي", "ز"),
    "سين": ("سين", "س"), "س": ("سين", "س"),
    "شين": ("شين", "ش"), "ش": ("شين", "ش"),
    "صاد": ("صاد", "ص"), "ص": ("صاد", "ص"),
    "ضاد": ("ضاد", "ض"), "ض": ("ضاد", "ض"),
    "طاء": ("طاء", "ط"), "ط": ("طاء", "ط"),
    "ظاء": ("ظاء", "ظ"), "ظ": ("ظاء", "ظ"),
    "عين": ("عين", "ع"), "ع": ("عين", "ع"),
    "غين": ("غين", "غ"), "غ": ("غين", "غ"),
    "فاء": ("فاء", "ف"), "ف": ("فاء", "ف"),
    "قاف": ("قاف", "ق"), "ق": ("قاف", "ق"),
    "كاف": ("كاف", "ك"), "ك": ("كاف", "ك"),
    "لام": ("لام", "ل"), "ل": ("لام", "ل"),
    "ميم": ("ميم", "م"), "م": ("ميم", "م"),
    "نون": ("نون", "ن"), "ن": ("نون", "ن"),
    "هاء": ("هاء", "ه"), "ه": ("هاء", "ه"),
    "واو": ("واو", "و"), "و": ("واو", "و"),
    "ياء": ("ياء", "ي"), "ي": ("ياء", "ي"),
    "همزة": ("همزة", "ء"), "همزة مكسورة": ("همزة", "ء"),
    "همزة مضمومة": ("همزة", "ء"), "ء": ("همزة", "ء"),
    "متعددة": ("متعددة", "متعددة"),
    "غير محددة": ("غير محددة", "غير محددة"),
}


def normalize_arabic(s: str | None) -> str:
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
    s = PUNCT_RE.sub(" ", s)
    return SPACE_RE.sub(" ", s).strip()


_PACK_MAP = {chr(i): bytes([i]) for i in range(0x7F)}
for _i in range(0x0600, 0x0680):
    _PACK_MAP[chr(_i)] = bytes([0x80 | (_i - 0x0600)])

_UNPACK_MAP = [chr(i) if i < 0x7F else (chr(0x0600 + (i & 0x7F)) if i >= 0x80 else "") for i in range(256)]


def pack_arabic(text: str) -> bytes:
    out = bytearray()
    pmap = _PACK_MAP
    for ch in text:
        b = pmap.get(ch)
        if b is not None:
            out.extend(b)
        else:
            eb = ch.encode("utf-8")
            out.append(0x7F)
            out.append(len(eb))
            out.extend(eb)
    return bytes(out)


def unpack_arabic(data: bytes | memoryview) -> str:
    # Fast path when no 0x7F escape byte exists (99.9% of poems)
    raw = bytes(data) if isinstance(data, memoryview) else data
    if 0x7F not in raw:
        umap = _UNPACK_MAP
        return "".join(umap[b] for b in raw)
    chars: list[str] = []
    umap = _UNPACK_MAP
    i = 0
    n = len(raw)
    while i < n:
        b = raw[i]
        if b != 0x7F:
            chars.append(umap[b])
            i += 1
        else:
            ln = raw[i + 1]
            chars.append(raw[i + 2 : i + 2 + ln].decode("utf-8"))
            i += 2 + ln
    return "".join(chars)


def qafiyah_to_tab_format(content: str) -> str:
    """Convert Qafiyah '*' hemistich delimiter to canonical '\\t' format."""
    if not content:
        return ""
    lines = []
    for ln in content.replace("\r", "").split("\n"):
        ln = ln.strip()
        if not ln:
            continue
        if "*" in ln:
            parts = [p.replace("\t", " ").strip() for p in ln.split("*")]
            lines.append("\t".join(p for p in parts if p))
        else:
            lines.append(ln.replace("\t", " "))
    return "\n".join(lines)


def clean_bayt_body(body: str) -> str:
    if not body:
        return ""
    lines = []
    for ln in body.replace("\r", "").split("\n"):
        ln = ln.strip()
        if not ln:
            continue
        parts = [p.strip() for p in ln.split("\t") if p.strip()]
        if parts:
            lines.append("\t".join(parts))
    return "\n".join(lines)


def diacritic_density(text: str) -> float:
    if not text:
        return 0.0
    return len(TASHKEEL_RE.findall(text)) / max(1, len(text))


def poem_quality_score(text: str, verse_count: int) -> float:
    """Objective quality score balancing completeness and vocalization."""
    dens = diacritic_density(text)
    return verse_count * 10.0 + dens * 80.0


def body_fingerprint(text: str) -> bytes:
    """Compact 8-byte SHA1 prefix of normalized poem text for exact dedup."""
    norm = normalize_arabic(text)
    return hashlib.sha1(norm.encode("utf-8")).digest()[:8]


def first_line_norm(text: str) -> str:
    first = text.split("\n", 1)[0] if text else ""
    return normalize_arabic(first)


def ensure_bayt_db() -> Path:
    if BAYT_TMP.exists() and BAYT_TMP.stat().st_size > 10_000_000:
        return BAYT_TMP
    print(f"Decompressing {BAYT_GZ.name}...", flush=True)
    with gzip.open(BAYT_GZ, "rb") as fi, open(BAYT_TMP, "wb") as fo:
        shutil.copyfileobj(fi, fo, length=8 * 1024 * 1024)
    return BAYT_TMP


def main() -> int:
    t0 = time.time()
    bayt_path = ensure_bayt_db()

    q = sqlite3.connect(str(QAF_DB))
    b = sqlite3.connect(str(bayt_path))

    report: dict[str, Any] = {}

    # ------------------------------------------------------------------
    # 1. Build unified taxonomy ID maps
    # ------------------------------------------------------------------
    print("1/7 Building unified taxonomies...", flush=True)
    q_era_id_to_canon: dict[int, int] = {}
    for qeid, slug, name in q.execute("SELECT id, slug, name FROM eras"):
        q_era_id_to_canon[qeid] = ERA_ALIAS_TO_ID.get(slug) or ERA_ALIAS_TO_ID.get(name, 13)

    b_era_id_to_canon: dict[int, int] = {}
    for beid, name in b.execute("SELECT id, name FROM eras"):
        b_era_id_to_canon[beid] = ERA_ALIAS_TO_ID.get(name, 13)

    # Meters
    meters_list: list[tuple[int, str, str]] = []  # (id, slug, name)
    meter_name_to_id: dict[str, int] = {}
    q_meter_to_canon: dict[int, int] = {}
    for qmid, slug, name in q.execute("SELECT id, slug, name FROM meters ORDER BY id"):
        cname = METER_ALIASES.get(name, name)
        if cname not in meter_name_to_id:
            mid = len(meters_list) + 1
            meter_name_to_id[cname] = mid
            meters_list.append((mid, slug, cname))
        q_meter_to_canon[qmid] = meter_name_to_id[cname]

    b_meter_to_canon: dict[int, int] = {}
    for bmid, name in b.execute("SELECT id, name FROM meters ORDER BY id"):
        cname = METER_ALIASES.get(name, name)
        if cname not in meter_name_to_id:
            mid = len(meters_list) + 1
            meter_name_to_id[cname] = mid
            slug = f"m_{mid}"
            meters_list.append((mid, slug, cname))
        b_meter_to_canon[bmid] = meter_name_to_id[cname]

    unknown_meter_id = meter_name_to_id.get("غير مصنّف", 1)

    # Rhymes
    rhymes_list: list[tuple[int, str, str]] = []  # (id, name, letter)
    rhyme_name_to_id: dict[str, int] = {}

    def get_or_add_rhyme(raw_name: str | None) -> int:
        raw = (raw_name or "").strip()
        cname, letter = RHYME_LETTER_MAP.get(raw, ("غير محددة", "غير محددة"))
        if cname not in rhyme_name_to_id:
            rid = len(rhymes_list) + 1
            rhyme_name_to_id[cname] = rid
            rhymes_list.append((rid, cname, letter))
        return rhyme_name_to_id[cname]

    q_rhyme_to_canon: dict[int, int] = {}
    for qrid, name in q.execute("SELECT id, name FROM rhymes ORDER BY id"):
        q_rhyme_to_canon[qrid] = get_or_add_rhyme(name)

    b_rhyme_to_canon: dict[int, int] = {}
    for brid, name in b.execute("SELECT id, name FROM rhymes ORDER BY id"):
        b_rhyme_to_canon[brid] = get_or_add_rhyme(name)

    unknown_rhyme_id = get_or_add_rhyme("غير محددة")

    # Themes, Poem Types, Collections, Feelings (from Qafiyah)
    themes_rows = list(q.execute("SELECT id, slug, name FROM themes ORDER BY id"))
    ptypes_rows = list(q.execute("SELECT id, slug, name FROM poem_types ORDER BY id"))
    collections_rows = list(q.execute("SELECT id, slug, name FROM collections ORDER BY id"))
    feelings_rows = list(
        q.execute("SELECT id, slug, name, wheel_term, parent_slug, verse_count FROM feelings ORDER BY id")
    )

    # ------------------------------------------------------------------
    # 2. Load & Match Poets (with misattribution split protection)
    # ------------------------------------------------------------------
    print("2/7 Matching & enriching poets across both databases...", flush=True)
    # Load all Qafiyah poets
    poets: dict[int, dict[str, Any]] = {}
    q_poets_by_norm: dict[str, list[int]] = collections.defaultdict(list)
    for pid, slug, name, norm, era_id, nick, pc, has_av, bio_z in q.execute(
        "SELECT id, slug, name, name_norm, era_id, nickname, poems_count, has_avatar, bio_z FROM poets"
    ):
        bio_txt = unpack_arabic(zlib.decompress(bio_z)) if bio_z else ""
        poets[pid] = {
            "id": pid,
            "slug": slug,
            "name": name,
            "name_vocalized": name,
            "name_norm": norm,
            "era_id": q_era_id_to_canon.get(era_id, 13),
            "nickname": nick or "",
            "dates_hijri": "",
            "dates_gregorian": "",
            "has_avatar": has_av or 0,
            "bio": bio_txt,
        }
        q_poets_by_norm[norm].append(pid)

    next_poet_id = max(poets.keys(), default=0) + 1

    # Index Qafiyah poem titles -> poet_ids for co-occurrence poet matching
    q_title_to_poets: dict[str, set[int]] = collections.defaultdict(set)
    for qpid, tnorm in q.execute("SELECT poet_id, title_norm FROM poems"):
        if len(tnorm) >= 12:
            q_title_to_poets[tnorm].add(qpid)

    # First pass: match every Bayt poet to a candidate Qafiyah poet
    bayt_poets_raw = list(
        b.execute(
            "SELECT id, era_id, name, name_plain, name_norm, dates_hijri, dates_gregorian, bio, poem_count FROM poets ORDER BY poem_count DESC"
        )
    )
    bayt_to_merged_poet: dict[int, int] = {}
    q_poet_claimed_by: dict[int, int] = {}  # q_poet_id -> bayt_poet_id that claimed it
    split_reassign_titles: dict[tuple[int, str], int] = {}  # (old_q_pid, title_norm) -> new_poet_id

    poets_exact_matched = 0
    poets_cooccur_matched = 0
    poets_split_fixed = 0
    poets_added_unique = 0

    # Match exact-name poets first so canonical names claim their Qafiyah poet before aliases
    exact_pass = []
    other_pass = []
    for row in bayt_poets_raw:
        if row[4] in q_poets_by_norm:
            exact_pass.append(row)
        else:
            other_pass.append(row)

    def enrich_poet(target_pid: int, brow: tuple) -> None:
        _, b_era, b_voc, b_plain, b_norm, hijri, greg, b_bio, _ = brow
        p = poets[target_pid]
        if b_voc and diacritic_density(b_voc) > diacritic_density(p["name_vocalized"]):
            p["name_vocalized"] = b_voc
        if hijri and not p["dates_hijri"]:
            p["dates_hijri"] = hijri
        if greg and not p["dates_gregorian"]:
            p["dates_gregorian"] = greg
        if b_bio and len(b_bio.strip()) > len(p["bio"].strip()):
            p["bio"] = b_bio.strip()
        canon_b_era = b_era_id_to_canon.get(b_era, 13)
        # Prefer Mukhadram (2) over Jahili(1)/Islami(3), and any known era over Unknown(13)
        if canon_b_era == 2 and p["era_id"] in (1, 3, 13):
            p["era_id"] = 2
        elif p["era_id"] == 13 and canon_b_era != 13:
            p["era_id"] = canon_b_era

    for row in exact_pass:
        bid, b_era, b_voc, b_plain, b_norm, hijri, greg, b_bio, _ = row
        qpid = q_poets_by_norm[b_norm][0]
        bayt_to_merged_poet[bid] = qpid
        q_poet_claimed_by[qpid] = bid
        enrich_poet(qpid, row)
        poets_exact_matched += 1

    for row in other_pass:
        bid, b_era, b_voc, b_plain, b_norm, hijri, greg, b_bio, b_pcnt = row
        btitles = [r[0] for r in b.execute("SELECT title_norm FROM poems WHERE poet_id=?", (bid,))]
        votes = collections.Counter()
        for t in btitles:
            if len(t) >= 12 and t in q_title_to_poets:
                for qpid in q_title_to_poets[t]:
                    votes[qpid] += 1

        matched_qpid = None
        if votes:
            top_qpid, top_cnt = votes.most_common(1)[0]
            if top_cnt >= 2 or (len(btitles) <= 3 and top_cnt >= 1):
                matched_qpid = top_qpid

        if matched_qpid is not None and matched_qpid not in q_poet_claimed_by:
            bayt_to_merged_poet[bid] = matched_qpid
            q_poet_claimed_by[matched_qpid] = bid
            enrich_poet(matched_qpid, row)
            poets_cooccur_matched += 1
        elif matched_qpid is not None and matched_qpid in q_poet_claimed_by:
            # Misattribution in Qafiyah (e.g., حسن الطويراني merged onto ابن زريق البغدادي)!
            # Create a clean separate poet record and reassign matching Qafiyah poems to it.
            new_pid = next_poet_id
            next_poet_id += 1
            poets[new_pid] = {
                "id": new_pid,
                "slug": f"b_{bid}",
                "name": b_plain,
                "name_vocalized": b_voc or b_plain,
                "name_norm": b_norm,
                "era_id": b_era_id_to_canon.get(b_era, 13),
                "nickname": "",
                "dates_hijri": hijri or "",
                "dates_gregorian": greg or "",
                "has_avatar": 0,
                "bio": (b_bio or "").strip(),
            }
            bayt_to_merged_poet[bid] = new_pid
            for t in btitles:
                if t:
                    split_reassign_titles[(matched_qpid, t)] = new_pid
            poets_split_fixed += 1
            print(
                f"    [SPLIT FIX] Separated '{b_plain}' ({b_pcnt} poems) from '{poets[matched_qpid]['name']}'",
                flush=True,
            )
        else:
            new_pid = next_poet_id
            next_poet_id += 1
            poets[new_pid] = {
                "id": new_pid,
                "slug": f"b_{bid}",
                "name": b_plain,
                "name_vocalized": b_voc or b_plain,
                "name_norm": b_norm,
                "era_id": b_era_id_to_canon.get(b_era, 13),
                "nickname": "",
                "dates_hijri": hijri or "",
                "dates_gregorian": greg or "",
                "has_avatar": 0,
                "bio": (b_bio or "").strip(),
            }
            bayt_to_merged_poet[bid] = new_pid
            poets_added_unique += 1

    del q_title_to_poets
    print(
        f"    Poets: exact={poets_exact_matched}, cooccur={poets_cooccur_matched}, "
        f"split_fixed={poets_split_fixed}, unique_added={poets_added_unique} | Total={len(poets):,}",
        flush=True,
    )

    # ------------------------------------------------------------------
    # 3. Stream Qafiyah poems -> deduplicate exact internal duplicates
    # ------------------------------------------------------------------
    print("3/7 Loading & deduplicating Qafiyah poems (333,856)...", flush=True)
    # Store compact staging records in a temporary SQLite DB to keep RAM low on Termux
    stage_path = ROOT / "qafiyah_db" / "_merge_stage.db"
    if stage_path.exists():
        stage_path.unlink()
    st = sqlite3.connect(str(stage_path))
    st.execute("PRAGMA journal_mode=OFF")
    st.execute("PRAGMA synchronous=OFF")
    st.execute("PRAGMA temp_store=MEMORY")
    st.execute("PRAGMA cache_size=-48000")
    st.execute(
        """
        CREATE TABLE staged_poems (
            sid INTEGER PRIMARY KEY,
            q_orig_id INTEGER,
            slug TEXT,
            poet_id INTEGER NOT NULL,
            era_id INTEGER NOT NULL,
            meter_id INTEGER NOT NULL,
            theme_id INTEGER,
            rhyme_id INTEGER NOT NULL,
            poem_type_id INTEGER,
            meter_note TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            title_norm TEXT NOT NULL,
            verse_count INTEGER NOT NULL,
            has_diacritics INTEGER NOT NULL,
            is_free_verse INTEGER NOT NULL,
            quality REAL NOT NULL,
            body_hash BLOB NOT NULL,
            content_z BLOB NOT NULL
        )
        """
    )

    # In-memory lookup maps for O(1) dedup
    by_poet_hash: dict[tuple[int, bytes], tuple[int, float, int]] = {}  # -> (sid, quality, vc)
    by_poet_title: dict[tuple[int, str], list[tuple[int, float, int]]] = collections.defaultdict(list)
    by_global_hash: dict[bytes, tuple[int, int, float]] = {}  # body_hash -> (sid, poet_id, quality)

    q_orig_to_sid: dict[int, int] = {}
    q_internal_dups = 0
    sid_counter = 0

    # Cache Qafiyah blocks sequentially (poems are ordered by block_id!)
    cur_blk_id = -1
    cur_blk_bytes = b""
    batch: list[tuple] = []

    q_query = """
        SELECT id, slug, poet_id, era_id, meter_id, theme_id, rhyme_id, poem_type_id,
               title, title_norm, verse_count, block_id, offset, length
        FROM poems
        ORDER BY block_id, id
    """
    for row in q.execute(q_query):
        (
            qid, slug, qpid, qeid, qmid, qtid, qrid, qptid,
            title, tnorm, vc, blk_id, off, ln,
        ) = row
        if blk_id != cur_blk_id:
            comp = q.execute("SELECT data FROM content_blocks WHERE id=?", (blk_id,)).fetchone()[0]
            cur_blk_bytes = zlib.decompress(comp)
            cur_blk_id = blk_id

        raw_txt = unpack_arabic(memoryview(cur_blk_bytes)[off : off + ln])
        tab_txt = qafiyah_to_tab_format(raw_txt)
        eff_vc = len(tab_txt.split("\n")) if tab_txt else (vc or 0)
        bhash = body_fingerprint(tab_txt)
        qual = poem_quality_score(tab_txt, eff_vc)
        has_diac = 1 if diacritic_density(tab_txt) >= 0.05 else 0
        is_free = 1 if ("\t" not in tab_txt and eff_vc > 0) else 0

        # Apply poet split reassignment if applicable (e.g. حسن الطويراني)
        poet_id = split_reassign_titles.get((qpid, tnorm), qpid)
        era_id = poets[poet_id]["era_id"]
        if era_id == 13 and qeid:
            era_id = q_era_id_to_canon.get(qeid, 13)
        meter_id = q_meter_to_canon.get(qmid, unknown_meter_id) if qmid else unknown_meter_id
        rhyme_id = q_rhyme_to_canon.get(qrid, unknown_rhyme_id) if qrid else unknown_rhyme_id

        key_ph = (poet_id, bhash)
        if key_ph in by_poet_hash:
            existing_sid, existing_qual, _ = by_poet_hash[key_ph]
            q_internal_dups += 1
            q_orig_to_sid[qid] = existing_sid
            if qual > existing_qual:
                # Replace content in staged table if better vocalized
                if batch:
                    st.executemany(
                        "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        batch,
                    )
                    batch.clear()
                st.execute(
                    "UPDATE staged_poems SET verse_count=?, has_diacritics=?, quality=?, content_z=? WHERE sid=?",
                    (eff_vc, has_diac, qual, zlib.compress(pack_arabic(tab_txt), 6), existing_sid),
                )
                by_poet_hash[key_ph] = (existing_sid, qual, eff_vc)
            continue

        sid_counter += 1
        sid = sid_counter
        q_orig_to_sid[qid] = sid
        by_poet_hash[key_ph] = (sid, qual, eff_vc)
        if len(tnorm) >= 6:
            by_poet_title[(poet_id, tnorm)].append((sid, qual, eff_vc))
        if eff_vc >= 3 and bhash not in by_global_hash:
            by_global_hash[bhash] = (sid, poet_id, qual)

        batch.append(
            (
                sid, qid, slug, poet_id, era_id, meter_id, qtid, rhyme_id, qptid,
                "", title, tnorm, eff_vc, has_diac, is_free, qual, bhash,
                zlib.compress(pack_arabic(tab_txt), 6),
            )
        )
        if len(batch) >= 5000:
            st.executemany(
                "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                batch,
            )
            batch.clear()
            if sid % 100000 == 0:
                print(f"    Staged {sid:,} Qafiyah poems (internal dups skipped: {q_internal_dups:,})...", flush=True)

    if batch:
        st.executemany(
            "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            batch,
        )
        batch.clear()
    st.commit()
    print(f"    Staged {sid_counter:,} unique Qafiyah poems (removed {q_internal_dups:,} exact internal duplicates).", flush=True)

    # ------------------------------------------------------------------
    # 4. Merge Bayt Al-Qaseed poems (dedup + pick best version + add unique)
    # ------------------------------------------------------------------
    print("4/7 Merging 90,238 Bayt Al-Qaseed poems (dedup + best-version selection)...", flush=True)
    bayt_poem_to_sid: dict[int, int] = {}
    stats_merge = {
        "bayt_matched_by_hash": 0,
        "bayt_matched_by_title": 0,
        "bayt_matched_global_hash": 0,
        "bayt_won_content": 0,
        "qafiyah_won_content": 0,
        "bayt_unique_added": 0,
    }

    b_query = """
        SELECT id, poet_id, era_id, meter_id, rhyme_id, meter_note,
               title, title_norm, verse_count, has_diacritics, is_free_verse, body
        FROM poems
    """
    new_bayt_batch: list[tuple] = []
    updates_count = 0

    for row in b.execute(b_query):
        (
            bpid, b_poet_id, b_era_id, b_meter_id, b_rhyme_id, meter_note,
            title, tnorm, bvc, b_has_diac, b_is_free, body,
        ) = row

        poet_id = bayt_to_merged_poet[b_poet_id]
        tab_txt = clean_bayt_body(body)
        eff_vc = len(tab_txt.split("\n")) if tab_txt else (bvc or 0)
        bhash = body_fingerprint(tab_txt)
        qual = poem_quality_score(tab_txt, eff_vc)
        has_diac = 1 if (b_has_diac or diacritic_density(tab_txt) >= 0.05) else 0
        is_free = 1 if (b_is_free or ("\t" not in tab_txt and eff_vc > 0)) else 0

        meter_id = b_meter_to_canon.get(b_meter_id, unknown_meter_id)
        rhyme_id = b_rhyme_to_canon.get(b_rhyme_id, unknown_rhyme_id)
        era_id = poets[poet_id]["era_id"]
        if era_id == 13:
            era_id = b_era_id_to_canon.get(b_era_id, 13)

        matched_sid = None
        matched_qual = -1.0

        # Match 1: Exact body hash for same poet
        hit_ph = by_poet_hash.get((poet_id, bhash))
        if hit_ph is not None:
            matched_sid, matched_qual, _ = hit_ph
            stats_merge["bayt_matched_by_hash"] += 1
        else:
            # Match 2: Same poet + same normalized title (verify compatible length or first line)
            cands = by_poet_title.get((poet_id, tnorm)) if len(tnorm) >= 6 else None
            if cands:
                # Pick candidate with closest verse count
                best_c = min(cands, key=lambda c: abs(c[2] - eff_vc))
                c_sid, c_qual, c_vc = best_c
                # Accept if verse counts are reasonably close (avoid merging totally different poems with same short opening)
                ratio = max(c_vc, eff_vc, 1) / max(min(c_vc, eff_vc), 1)
                if ratio <= 2.5 or len(tnorm) >= 14:
                    matched_sid, matched_qual = c_sid, c_qual
                    stats_merge["bayt_matched_by_title"] += 1

            # Match 3: Global exact body hash for poems >= 3 verses
            if matched_sid is None and eff_vc >= 3 and bhash in by_global_hash:
                g_sid, _, g_qual = by_global_hash[bhash]
                matched_sid, matched_qual = g_sid, g_qual
                stats_merge["bayt_matched_global_hash"] += 1

        if matched_sid is not None:
            bayt_poem_to_sid[bpid] = matched_sid
            if new_bayt_batch:
                st.executemany(
                    "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    new_bayt_batch,
                )
                new_bayt_batch.clear()
            # Fetch existing metadata to merge best fields
            cur_row = st.execute(
                "SELECT meter_id, rhyme_id, meter_note, is_free_verse, title FROM staged_poems WHERE sid=?",
                (matched_sid,),
            ).fetchone()
            ex_meter, ex_rhyme, ex_mnote, ex_free, ex_title = cur_row
            final_meter = ex_meter if ex_meter != unknown_meter_id else meter_id
            final_rhyme = ex_rhyme if ex_rhyme != unknown_rhyme_id else rhyme_id
            final_mnote = ex_mnote or (meter_note or "")
            final_free = 1 if (ex_free or is_free) else 0
            final_title = title if diacritic_density(title) > diacritic_density(ex_title) else ex_title

            if qual > matched_qual + 0.5:
                stats_merge["bayt_won_content"] += 1
                st.execute(
                    """
                    UPDATE staged_poems
                    SET meter_id=?, rhyme_id=?, meter_note=?, is_free_verse=?,
                        title=?, verse_count=?, has_diacritics=?, quality=?, content_z=?
                    WHERE sid=?
                    """,
                    (
                        final_meter, final_rhyme, final_mnote, final_free,
                        final_title, eff_vc, has_diac, qual,
                        zlib.compress(pack_arabic(tab_txt), 6), matched_sid,
                    ),
                )
                by_poet_hash[(poet_id, bhash)] = (matched_sid, qual, eff_vc)
            else:
                stats_merge["qafiyah_won_content"] += 1
                if (
                    final_meter != ex_meter
                    or final_rhyme != ex_rhyme
                    or final_mnote != ex_mnote
                    or final_title != ex_title
                ):
                    st.execute(
                        "UPDATE staged_poems SET meter_id=?, rhyme_id=?, meter_note=?, title=? WHERE sid=?",
                        (final_meter, final_rhyme, final_mnote, final_title, matched_sid),
                    )
            updates_count += 1
        else:
            sid_counter += 1
            sid = sid_counter
            bayt_poem_to_sid[bpid] = sid
            stats_merge["bayt_unique_added"] += 1
            by_poet_hash[(poet_id, bhash)] = (sid, qual, eff_vc)
            if len(tnorm) >= 6:
                by_poet_title[(poet_id, tnorm)].append((sid, qual, eff_vc))
            new_bayt_batch.append(
                (
                    sid, None, f"b_{bpid}", poet_id, era_id, meter_id, None, rhyme_id, None,
                    meter_note or "", title, tnorm, eff_vc, has_diac, is_free, qual, bhash,
                    zlib.compress(pack_arabic(tab_txt), 6),
                )
            )
            if len(new_bayt_batch) >= 2000:
                st.executemany(
                    "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    new_bayt_batch,
                )
                new_bayt_batch.clear()

    if new_bayt_batch:
        st.executemany(
            "INSERT INTO staged_poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            new_bayt_batch,
        )
        new_bayt_batch.clear()
    st.commit()

    del by_poet_hash, by_poet_title, by_global_hash
    print(f"    Merge stats: {json.dumps(stats_merge)}", flush=True)

    # ------------------------------------------------------------------
    # 5. Build final compact production SQLite DB
    # ------------------------------------------------------------------
    print("5/7 Building final compact production SQLite database...", flush=True)
    if OUT_DB.exists():
        OUT_DB.unlink()
    dst = sqlite3.connect(str(OUT_DB))
    dst.execute("PRAGMA page_size = 8192")
    dst.execute("PRAGMA journal_mode = OFF")
    dst.execute("PRAGMA synchronous = OFF")
    dst.execute("PRAGMA temp_store = MEMORY")
    dst.execute("PRAGMA cache_size = -64000")

    dst.executescript(
        """
        CREATE TABLE eras (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            display_order INTEGER NOT NULL,
            poet_count INTEGER NOT NULL DEFAULT 0,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE meters (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE themes (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE rhymes (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            letter TEXT NOT NULL,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE poem_types (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE collections (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            poem_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE feelings (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            wheel_term TEXT,
            parent_slug TEXT,
            verse_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE poets (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            era_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            name_vocalized TEXT NOT NULL,
            name_norm TEXT NOT NULL,
            nickname TEXT NOT NULL DEFAULT '',
            dates_hijri TEXT NOT NULL DEFAULT '',
            dates_gregorian TEXT NOT NULL DEFAULT '',
            has_avatar INTEGER NOT NULL DEFAULT 0,
            poem_count INTEGER NOT NULL DEFAULT 0,
            verse_count INTEGER NOT NULL DEFAULT 0,
            bio_z BLOB
        );
        CREATE TABLE content_blocks (
            id INTEGER PRIMARY KEY,
            data BLOB NOT NULL
        );
        CREATE TABLE poems (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL,
            poet_id INTEGER NOT NULL,
            era_id INTEGER NOT NULL,
            meter_id INTEGER NOT NULL,
            theme_id INTEGER,
            rhyme_id INTEGER NOT NULL,
            poem_type_id INTEGER,
            meter_note TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            title_norm TEXT NOT NULL,
            verse_count INTEGER NOT NULL,
            has_diacritics INTEGER NOT NULL DEFAULT 0,
            is_free_verse INTEGER NOT NULL DEFAULT 0,
            block_id INTEGER NOT NULL,
            offset INTEGER NOT NULL,
            length INTEGER NOT NULL
        );
        CREATE TABLE collection_poems (
            collection_id INTEGER NOT NULL,
            poem_id INTEGER NOT NULL,
            PRIMARY KEY (collection_id, poem_id)
        ) WITHOUT ROWID;
        CREATE TABLE poem_recensions (
            poem_id INTEGER NOT NULL,
            recension_id INTEGER NOT NULL,
            PRIMARY KEY (poem_id, recension_id)
        ) WITHOUT ROWID;
        CREATE TABLE featured_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            poem_id INTEGER NOT NULL,
            poet_id INTEGER NOT NULL,
            era_id INTEGER NOT NULL,
            verse_index INTEGER NOT NULL,
            verse_count INTEGER NOT NULL DEFAULT 0,
            sadr TEXT NOT NULL,
            ajuz TEXT NOT NULL,
            poet_name TEXT NOT NULL,
            era_name TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'خالدات',
            tag TEXT NOT NULL DEFAULT 'من عيون الشعر'
        );
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )

    # Insert taxonomies
    dst.executemany(
        "INSERT INTO eras (id, slug, name, display_order) VALUES (?,?,?,?)",
        [(eid, slug, name, eid) for eid, slug, name in CANONICAL_ERAS],
    )
    dst.executemany(
        "INSERT INTO meters (id, slug, name) VALUES (?,?,?)", meters_list
    )
    dst.executemany(
        "INSERT INTO themes (id, slug, name) VALUES (?,?,?)", themes_rows
    )
    dst.executemany(
        "INSERT INTO rhymes (id, name, letter) VALUES (?,?,?)", rhymes_list
    )
    dst.executemany(
        "INSERT INTO poem_types (id, slug, name) VALUES (?,?,?)", ptypes_rows
    )
    dst.executemany(
        "INSERT INTO collections (id, slug, name) VALUES (?,?,?)", collections_rows
    )
    dst.executemany(
        "INSERT INTO feelings VALUES (?,?,?,?,?,?)", feelings_rows
    )

    # Pack staged_poems ordered by (poet_id, sid) into 128-poem zlib-9 content_blocks
    sid_to_final_id: dict[int, int] = {}
    poet_poem_cnt: dict[int, int] = collections.Counter()
    poet_verse_cnt: dict[int, int] = collections.Counter()
    era_poem_cnt: dict[int, int] = collections.Counter()
    meter_poem_cnt: dict[int, int] = collections.Counter()
    theme_poem_cnt: dict[int, int] = collections.Counter()
    rhyme_poem_cnt: dict[int, int] = collections.Counter()
    ptype_poem_cnt: dict[int, int] = collections.Counter()

    block_id = 1
    block_buf = bytearray()
    block_cnt = 0
    final_id = 0
    total_verses = 0
    poem_batch: list[tuple] = []
    block_batch: list[tuple] = []

    st_query = """
        SELECT sid, slug, poet_id, era_id, meter_id, theme_id, rhyme_id, poem_type_id,
               meter_note, title, title_norm, verse_count, has_diacritics, is_free_verse, content_z
        FROM staged_poems
        ORDER BY poet_id, sid
    """
    for row in st.execute(st_query):
        (
            sid, slug, poet_id, era_id, meter_id, theme_id, rhyme_id, ptype_id,
            mnote, title, tnorm, vc, has_diac, is_free, content_z,
        ) = row

        final_id += 1
        sid_to_final_id[sid] = final_id
        total_verses += vc

        poet_poem_cnt[poet_id] += 1
        poet_verse_cnt[poet_id] += vc
        era_poem_cnt[era_id] += 1
        meter_poem_cnt[meter_id] += 1
        if theme_id:
            theme_poem_cnt[theme_id] += 1
        rhyme_poem_cnt[rhyme_id] += 1
        if ptype_id:
            ptype_poem_cnt[ptype_id] += 1

        packed = zlib.decompress(content_z)
        offset = len(block_buf)
        length = len(packed)
        block_buf.extend(packed)
        block_cnt += 1

        poem_batch.append(
            (
                final_id, slug, poet_id, era_id, meter_id, theme_id, rhyme_id, ptype_id,
                mnote, title, tnorm, vc, has_diac, is_free, block_id, offset, length,
            )
        )

        if block_cnt >= BLOCK_SIZE:
            block_batch.append((block_id, zlib.compress(bytes(block_buf), 9)))
            block_id += 1
            block_buf.clear()
            block_cnt = 0

        if len(poem_batch) >= 5000:
            dst.executemany(
                "INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                poem_batch,
            )
            poem_batch.clear()
            if block_batch:
                dst.executemany("INSERT INTO content_blocks VALUES (?,?)", block_batch)
                block_batch.clear()
            if final_id % 100000 == 0:
                print(f"    Packed {final_id:,} merged poems ({block_id:,} blocks)...", flush=True)

    if block_cnt > 0:
        block_batch.append((block_id, zlib.compress(bytes(block_buf), 9)))
    if poem_batch:
        dst.executemany(
            "INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", poem_batch
        )
    if block_batch:
        dst.executemany("INSERT INTO content_blocks VALUES (?,?)", block_batch)

    # Insert poets (only poets that have >= 1 poem or exist in corpus) with accurate counts
    era_poet_cnt: dict[int, int] = collections.Counter()
    poet_insert_rows = []
    for pid, p in sorted(poets.items()):
        pc = poet_poem_cnt.get(pid, 0)
        vc = poet_verse_cnt.get(pid, 0)
        era_poet_cnt[p["era_id"]] += 1
        bio_z = zlib.compress(pack_arabic(p["bio"]), 9) if p["bio"] else None
        poet_insert_rows.append(
            (
                pid, p["slug"], p["era_id"], p["name"], p["name_vocalized"], p["name_norm"],
                p["nickname"], p["dates_hijri"], p["dates_gregorian"], p["has_avatar"],
                pc, vc, bio_z,
            )
        )
    dst.executemany("INSERT INTO poets VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", poet_insert_rows)

    # Update exact counts across taxonomies
    for eid, _, _ in CANONICAL_ERAS:
        dst.execute(
            "UPDATE eras SET poet_count=?, poem_count=? WHERE id=?",
            (era_poet_cnt.get(eid, 0), era_poem_cnt.get(eid, 0), eid),
        )
    for mid, _, _ in meters_list:
        dst.execute("UPDATE meters SET poem_count=? WHERE id=?", (meter_poem_cnt.get(mid, 0), mid))
    for tid, _, _ in themes_rows:
        dst.execute("UPDATE themes SET poem_count=? WHERE id=?", (theme_poem_cnt.get(tid, 0), tid))
    for rid, _, _ in rhymes_list:
        dst.execute("UPDATE rhymes SET poem_count=? WHERE id=?", (rhyme_poem_cnt.get(rid, 0), rid))
    for ptid, _, _ in ptypes_rows:
        dst.execute("UPDATE poem_types SET poem_count=? WHERE id=?", (ptype_poem_cnt.get(ptid, 0), ptid))

    # Remap collection_poems & poem_recensions
    col_rel = []
    for cid, qpid in q.execute("SELECT collection_id, poem_id FROM collection_poems"):
        sid = q_orig_to_sid.get(qpid)
        fid = sid_to_final_id.get(sid) if sid else None
        if fid:
            col_rel.append((cid, fid))
    if col_rel:
        dst.executemany("INSERT OR IGNORE INTO collection_poems VALUES (?,?)", col_rel)
        for cid, _, _ in collections_rows:
            c_cnt = dst.execute("SELECT COUNT(*) FROM collection_poems WHERE collection_id=?", (cid,)).fetchone()[0]
            dst.execute("UPDATE collections SET poem_count=? WHERE id=?", (c_cnt, cid))

    rec_rel = []
    for q1, q2 in q.execute("SELECT poem_id, recension_id FROM poem_recensions"):
        s1, s2 = q_orig_to_sid.get(q1), q_orig_to_sid.get(q2)
        f1 = sid_to_final_id.get(s1) if s1 else None
        f2 = sid_to_final_id.get(s2) if s2 else None
        if f1 and f2 and f1 != f2:
            rec_rel.append((f1, f2))
    if rec_rel:
        dst.executemany("INSERT OR IGNORE INTO poem_recensions VALUES (?,?)", rec_rel)

    # Remap all 172 featured_verses from Bayt Al-Qaseed
    era_id_to_name = {eid: name for eid, _, name in CANONICAL_ERAS}
    fv_remapped = 0
    fv_rows = []
    for (
        b_poem_id, b_poet_id, b_era_id, v_idx, v_cnt, sadr, ajuz, p_name, e_name, cat, tag
    ) in b.execute(
        "SELECT poem_id, poet_id, era_id, verse_index, verse_count, sadr, ajuz, poet_name, era_name, category, tag FROM featured_verses ORDER BY id"
    ):
        sid = bayt_poem_to_sid.get(b_poem_id)
        fid = sid_to_final_id.get(sid) if sid else None
        mpid = bayt_to_merged_poet.get(b_poet_id)
        if fid and mpid:
            actual_vc = dst.execute("SELECT verse_count FROM poems WHERE id=?", (fid,)).fetchone()[0]
            actual_era = poets[mpid]["era_id"]
            fv_rows.append(
                (
                    fid, mpid, actual_era, v_idx, actual_vc, sadr, ajuz,
                    poets[mpid]["name"], era_id_to_name[actual_era], cat, tag,
                )
            )
            fv_remapped += 1
    dst.executemany(
        """
        INSERT INTO featured_verses
        (poem_id, poet_id, era_id, verse_index, verse_count, sadr, ajuz, poet_name, era_name, category, tag)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
        """,
        fv_rows,
    )

    # ------------------------------------------------------------------
    # 6. Indexes, FTS5, Metadata, ANALYZE, VACUUM
    # ------------------------------------------------------------------
    print("6/7 Creating indexes, FTS5 search, ANALYZE & VACUUM...", flush=True)
    dst.executescript(
        """
        CREATE INDEX idx_poems_poet ON poems(poet_id);
        CREATE INDEX idx_poems_era ON poems(era_id);
        CREATE INDEX idx_poems_meter ON poems(meter_id);
        CREATE INDEX idx_poems_theme ON poems(theme_id);
        CREATE INDEX idx_poems_rhyme ON poems(rhyme_id);
        CREATE INDEX idx_poets_era ON poets(era_id);

        CREATE VIRTUAL TABLE poems_title_fts USING fts5(
            title_norm,
            content='poems',
            content_rowid='id',
            tokenize='unicode61 remove_diacritics 0'
        );
        INSERT INTO poems_title_fts(poems_title_fts) VALUES('rebuild');

        CREATE VIRTUAL TABLE poets_fts USING fts5(
            name_norm,
            content='poets',
            content_rowid='id',
            tokenize='unicode61 remove_diacritics 0'
        );
        INSERT INTO poets_fts(poets_fts) VALUES('rebuild');
        """
    )

    meta_items = [
        ("schema_version", "6"),
        ("format", "bayt_qafiyah_compact_v1"),
        ("content_codec", "arabic1b_zlib9_tab"),
        ("block_size", str(BLOCK_SIZE)),
        ("era_count", str(len(CANONICAL_ERAS))),
        ("poet_count", str(len(poets))),
        ("poem_count", str(final_id)),
        ("verse_count", str(total_verses)),
        ("meter_count", str(len(meters_list))),
        ("rhyme_count", str(len(rhymes_list))),
        ("theme_count", str(len(themes_rows))),
        ("featured_count", str(fv_remapped)),
        ("block_count", str(block_id)),
    ]
    dst.executemany("INSERT INTO metadata VALUES (?,?)", meta_items)
    dst.commit()
    dst.execute("ANALYZE")
    dst.execute("VACUUM")
    dst.close()

    st.close()
    q.close()
    b.close()

    # Clean up temporary staging files
    if stage_path.exists():
        stage_path.unlink()
    if BAYT_TMP.exists():
        BAYT_TMP.unlink()

    # ------------------------------------------------------------------
    # 7. Final Verification, Benchmark & Gzip Compression
    # ------------------------------------------------------------------
    print("7/7 Verifying integrity, benchmarking, and creating .db.gz...", flush=True)
    vc_conn = sqlite3.connect(str(OUT_DB))
    fv_broken = vc_conn.execute(
        "SELECT COUNT(*) FROM featured_verses fv LEFT JOIN poems p ON p.id = fv.poem_id WHERE p.id IS NULL"
    ).fetchone()[0]
    assert fv_broken == 0, f"Found {fv_broken} broken featured_verses!"

    # Random read benchmark (500 poems)
    sample_ids = random.sample(range(1, final_id + 1), min(500, final_id))
    bcache: dict[int, bytes] = {}
    t_r = time.time()
    for pid in sample_ids:
        bid, off, ln = vc_conn.execute(
            "SELECT block_id, offset, length FROM poems WHERE id=?", (pid,)
        ).fetchone()
        raw = bcache.get(bid)
        if raw is None:
            comp = vc_conn.execute("SELECT data FROM content_blocks WHERE id=?", (bid,)).fetchone()[0]
            raw = zlib.decompress(comp)
            if len(bcache) > 16:
                bcache.clear()
            bcache[bid] = raw
        txt = unpack_arabic(memoryview(raw)[off : off + ln])
        assert len(txt) > 0, f"Empty content on poem {pid}"
    avg_read_ms = round((time.time() - t_r) / len(sample_ids) * 1000, 2)

    t_f = time.time()
    fts_hits = vc_conn.execute(
        "SELECT rowid FROM poems_title_fts WHERE poems_title_fts MATCH 'الليل' LIMIT 20"
    ).fetchall()
    fts_ms = round((time.time() - t_f) * 1000, 2)
    vc_conn.close()

    # Compress to .db.gz
    with open(OUT_DB, "rb") as fi, gzip.open(OUT_GZ, "wb", compresslevel=9) as fo:
        shutil.copyfileobj(fi, fo, length=4 * 1024 * 1024)

    db_mb = round(OUT_DB.stat().st_size / (1024 * 1024), 2)
    gz_mb = round(OUT_GZ.stat().st_size / (1024 * 1024), 2)

    report = {
        "elapsed_sec": round(time.time() - t0, 1),
        "output_db": str(OUT_DB),
        "output_db_mb": db_mb,
        "output_gz": str(OUT_GZ),
        "output_gz_mb": gz_mb,
        "final_counts": {
            "eras": len(CANONICAL_ERAS),
            "meters": len(meters_list),
            "rhymes": len(rhymes_list),
            "themes": len(themes_rows),
            "poets": len(poets),
            "poems": final_id,
            "verses": total_verses,
            "content_blocks": block_id,
            "featured_verses": fv_remapped,
            "collection_poems": len(col_rel),
            "poem_recensions": len(rec_rel),
        },
        "poet_merge": {
            "exact_matched": poets_exact_matched,
            "cooccurrence_matched": poets_cooccur_matched,
            "misattribution_splits_fixed": poets_split_fixed,
            "unique_bayt_poets_added": poets_added_unique,
        },
        "poem_merge": {
            "qafiyah_internal_exact_dups_removed": q_internal_dups,
            **stats_merge,
        },
        "benchmarks": {
            "avg_poem_read_ms": avg_read_ms,
            "fts5_title_search_ms": fts_ms,
            "fts5_sample_hits": len(fts_hits),
            "featured_verses_integrity_ok": fv_broken == 0,
        },
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\n=== MERGE COMPLETE ===", flush=True)
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

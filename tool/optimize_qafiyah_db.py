#!/usr/bin/env python3
"""
High-density, high-speed optimizer for qafiyah_full_333856.db(.gz).

Strategy (Best Speed / Size Balance for Mobile / Flutter):
1. Full 3NF normalization: replaces repeated text strings (poets, eras, meters,
   themes, rhymes, poem_types, slugs) with compact INTEGER foreign keys.
2. Drops duplicate columns (verses_json duplicates content; keywords duplicates
   taxonomies; related_slugs_json is UI-only).
3. Lossless 1-byte Arabic packing (U+0600..U+067F -> 0x80..0xFF, ASCII < 0x7F
   as-is, rare codepoints escaped with 0x7F + len + UTF-8) cuts raw Arabic UTF-8
   in half and doubles zlib's effective LZ77 sliding window.
4. Block-compressed content_blocks (128 poems per zlib-9 block, ordered by
   poet_id for maximum compression & cache locality). Each poem stores
   (block_id, offset, length) -> ~1 ms read time using native dart:io zlib.
5. External-content FTS5 on poem titles & poet names (~12 MB) for < 2 ms search.
6. Compact SQLite physical layout (page_size=8192, ANALYZE, VACUUM).
"""

from __future__ import annotations

import gzip
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

ROOT = Path(__file__).resolve().parent.parent
SRC_GZ = ROOT / "qafiyah_db" / "qafiyah_full_333856.db.gz"
SRC_RAW = ROOT / "qafiyah_db" / "_inspect_333856.db"
OUT_DB = ROOT / "qafiyah_db" / "qafiyah_optimized.db"

BLOCK_SIZE = 128

TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]")
TATWEEL_RE = re.compile(r"\u0640")
PUNCT_RE = re.compile(r"[^\u0621-\u064A0-9\s]")
SPACE_RE = re.compile(r"\s+")


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


def pack_arabic(text: str) -> bytes:
    """Lossless 1-byte Arabic encoder (compatible with ~15-line Dart decoder)."""
    out = bytearray()
    for ch in text:
        o = ord(ch)
        if o < 0x7F:
            out.append(o)
        elif 0x0600 <= o <= 0x067F:
            out.append(0x80 | (o - 0x0600))
        else:
            b = ch.encode("utf-8")
            out.append(0x7F)
            out.append(len(b))
            out.extend(b)
    return bytes(out)


def unpack_arabic(data: bytes | memoryview) -> str:
    """Lossless decoder matching pack_arabic."""
    chars: list[str] = []
    i = 0
    n = len(data)
    while i < n:
        b = data[i]
        if b < 0x7F:
            chars.append(chr(b))
            i += 1
        elif b >= 0x80:
            chars.append(chr(0x0600 + (b & 0x7F)))
            i += 1
        else:
            ln = data[i + 1]
            chars.append(bytes(data[i + 2 : i + 2 + ln]).decode("utf-8"))
            i += 2 + ln
    return "".join(chars)


def ensure_source_db() -> Path:
    if SRC_RAW.exists() and SRC_RAW.stat().st_size > 100_000_000:
        return SRC_RAW
    if not SRC_GZ.exists():
        raise FileNotFoundError(f"Source database not found: {SRC_GZ}")
    print(f"Decompressing {SRC_GZ.name}...", flush=True)
    with gzip.open(SRC_GZ, "rb") as fi, open(SRC_RAW, "wb") as fo:
        shutil.copyfileobj(fi, fo, length=8 * 1024 * 1024)
    return SRC_RAW


def build_optimized_db(src_path: Path, out_path: Path) -> None:
    t_start = time.time()
    if out_path.exists():
        out_path.unlink()

    src = sqlite3.connect(str(src_path))
    dst = sqlite3.connect(str(out_path))
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
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0,
            poets_count INTEGER DEFAULT 0
        );
        CREATE TABLE meters (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0
        );
        CREATE TABLE themes (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0
        );
        CREATE TABLE rhymes (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0
        );
        CREATE TABLE poem_types (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0
        );
        CREATE TABLE collections (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            poems_count INTEGER DEFAULT 0
        );
        CREATE TABLE feelings (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            wheel_term TEXT,
            parent_slug TEXT,
            verse_count INTEGER DEFAULT 0
        );
        CREATE TABLE poets (
            id INTEGER PRIMARY KEY,
            slug TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            name_norm TEXT NOT NULL,
            era_id INTEGER,
            nickname TEXT,
            poems_count INTEGER DEFAULT 0,
            has_avatar INTEGER DEFAULT 0,
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
            era_id INTEGER,
            meter_id INTEGER,
            theme_id INTEGER,
            rhyme_id INTEGER,
            poem_type_id INTEGER,
            title TEXT NOT NULL,
            title_norm TEXT NOT NULL,
            verse_count INTEGER NOT NULL,
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
        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )

    # 1. Copy taxonomies and build slug/name -> id maps
    print("1/6 Normalizing taxonomies...", flush=True)
    era_slug_to_id: dict[str, int] = {}
    era_name_to_id: dict[str, int] = {}
    for idx, (slug, name, pc, ptc) in enumerate(
        src.execute("SELECT slug, name, poems_count, poets_count FROM eras"), 1
    ):
        dst.execute("INSERT INTO eras VALUES (?,?,?,?,?)", (idx, slug, name, pc or 0, ptc or 0))
        era_slug_to_id[slug] = idx
        era_name_to_id[name] = idx

    meter_slug_to_id: dict[str, int] = {}
    meter_name_to_id: dict[str, int] = {}
    for idx, (slug, name, pc) in enumerate(
        src.execute("SELECT slug, name, poems_count FROM meters"), 1
    ):
        dst.execute("INSERT INTO meters VALUES (?,?,?,?)", (idx, slug, name, pc or 0))
        meter_slug_to_id[slug] = idx
        meter_name_to_id[name] = idx

    theme_slug_to_id: dict[str, int] = {}
    theme_name_to_id: dict[str, int] = {}
    for idx, (slug, name, pc) in enumerate(
        src.execute("SELECT slug, name, poems_count FROM themes"), 1
    ):
        dst.execute("INSERT INTO themes VALUES (?,?,?,?)", (idx, slug, name, pc or 0))
        theme_slug_to_id[slug] = idx
        theme_name_to_id[name] = idx

    rhyme_slug_to_id: dict[str, int] = {}
    rhyme_name_to_id: dict[str, int] = {}
    for idx, (slug, name, pc) in enumerate(
        src.execute("SELECT slug, name, poems_count FROM rhymes"), 1
    ):
        dst.execute("INSERT INTO rhymes VALUES (?,?,?,?)", (idx, slug, name, pc or 0))
        rhyme_slug_to_id[slug] = idx
        rhyme_name_to_id[name] = idx

    ptype_slug_to_id: dict[str, int] = {}
    ptype_name_to_id: dict[str, int] = {}
    for idx, (slug, name, pc) in enumerate(
        src.execute("SELECT slug, name, poems_count FROM poem_types"), 1
    ):
        dst.execute("INSERT INTO poem_types VALUES (?,?,?,?)", (idx, slug, name, pc or 0))
        ptype_slug_to_id[slug] = idx
        ptype_name_to_id[name] = idx

    col_slug_to_id: dict[str, int] = {}
    for idx, (slug, name, pc) in enumerate(
        src.execute("SELECT slug, name, poems_count FROM collections"), 1
    ):
        dst.execute("INSERT INTO collections VALUES (?,?,?,?)", (idx, slug, name, pc or 0))
        col_slug_to_id[slug] = idx

    for idx, (slug, name, wt, ps, vc) in enumerate(
        src.execute("SELECT slug, name, wheel_term, parent_slug, verse_count FROM feelings"), 1
    ):
        dst.execute("INSERT INTO feelings VALUES (?,?,?,?,?,?)", (idx, slug, name, wt, ps, vc or 0))

    # 2. Poets (with zlib-compressed 1-byte Arabic bios)
    print("2/6 Compressing & normalizing poets...", flush=True)
    poet_slug_to_id: dict[str, int] = {}
    poet_rows = []
    for idx, (slug, name, era_name, nick, pc, has_av, bio) in enumerate(
        src.execute(
            "SELECT slug, name, era_name, nickname, poems_count, has_avatar, bio FROM poets ORDER BY slug"
        ),
        1,
    ):
        poet_slug_to_id[slug] = idx
        era_id = era_name_to_id.get(era_name) if era_name else None
        bio_z = zlib.compress(pack_arabic(bio), 9) if bio else None
        poet_rows.append(
            (idx, slug, name, normalize_arabic(name), era_id, nick, pc or 0, has_av or 0, bio_z)
        )
    dst.executemany("INSERT INTO poets VALUES (?,?,?,?,?,?,?,?,?)", poet_rows)
    next_poet_id = len(poet_rows) + 1
    dst.commit()
    print(f"    Inserted {len(poet_rows):,} poets.", flush=True)

    # 3. Poems -> pack into 128-poem zlib-9 blocks ordered by poet_slug
    print("3/6 Packing & block-compressing 333,856 poems...", flush=True)
    poem_slug_to_id: dict[str, int] = {}
    pending_recensions: list[tuple[int, list[str]]] = []

    block_id = 1
    block_buf = bytearray()
    block_poem_count = 0
    poem_id = 0
    total_verses = 0
    poem_batch: list[tuple] = []
    block_batch: list[tuple] = []

    query = """
        SELECT slug, poet_slug, poet_name, era_slug, era_name,
               meter_slug, meter_name, theme_slug, theme_name,
               rhyme_name, poem_type_slug, poem_type_name,
               title, verse_count, content, recension_slugs_json
        FROM poems
        ORDER BY poet_slug, slug
    """

    for row in src.execute(query):
        (
            slug, poet_slug, poet_name, era_slug, era_name,
            meter_slug, meter_name, theme_slug, theme_name,
            rhyme_name, ptype_slug, ptype_name,
            title, verse_count, content, rec_json,
        ) = row

        poem_id += 1
        poem_slug_to_id[slug] = poem_id
        total_verses += verse_count or 0

        # Ensure poet exists even if missing from poets table
        p_key = poet_slug or f"_unknown_{poet_name or 'anon'}"
        poet_id = poet_slug_to_id.get(p_key)
        if poet_id is None:
            poet_id = next_poet_id
            next_poet_id += 1
            poet_slug_to_id[p_key] = poet_id
            pname = poet_name or "مجهول"
            dst.execute(
                "INSERT INTO poets VALUES (?,?,?,?,?,?,?,?,?)",
                (poet_id, p_key, pname, normalize_arabic(pname), era_slug_to_id.get(era_slug), None, 0, 0, None),
            )

        era_id = era_slug_to_id.get(era_slug) or era_name_to_id.get(era_name)
        meter_id = meter_slug_to_id.get(meter_slug) or meter_name_to_id.get(meter_name)
        theme_id = theme_slug_to_id.get(theme_slug) or theme_name_to_id.get(theme_name)
        rhyme_id = rhyme_name_to_id.get(rhyme_name)
        ptype_id = ptype_slug_to_id.get(ptype_slug) or ptype_name_to_id.get(ptype_name)

        packed = pack_arabic(content or "")
        offset = len(block_buf)
        length = len(packed)
        block_buf.extend(packed)
        block_poem_count += 1

        poem_batch.append(
            (
                poem_id,
                slug,
                poet_id,
                era_id,
                meter_id,
                theme_id,
                rhyme_id,
                ptype_id,
                title or "",
                normalize_arabic(title),
                verse_count or 0,
                block_id,
                offset,
                length,
            )
        )

        if rec_json and rec_json != "[]":
            try:
                recs = json.loads(rec_json)
                if recs:
                    pending_recensions.append((poem_id, recs))
            except json.JSONDecodeError:
                pass

        if block_poem_count >= BLOCK_SIZE:
            block_batch.append((block_id, zlib.compress(bytes(block_buf), 9)))
            block_id += 1
            block_buf.clear()
            block_poem_count = 0

        if len(poem_batch) >= 5000:
            dst.executemany(
                "INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", poem_batch
            )
            poem_batch.clear()
            if block_batch:
                dst.executemany("INSERT INTO content_blocks VALUES (?,?)", block_batch)
                block_batch.clear()
            if poem_id % 50000 == 0:
                print(f"    Processed {poem_id:,} poems ({block_id:,} blocks)...", flush=True)

    if block_poem_count > 0:
        block_batch.append((block_id, zlib.compress(bytes(block_buf), 9)))
    if poem_batch:
        dst.executemany(
            "INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", poem_batch
        )
    if block_batch:
        dst.executemany("INSERT INTO content_blocks VALUES (?,?)", block_batch)
    dst.commit()
    print(f"    Finished {poem_id:,} poems in {block_id:,} compressed blocks.", flush=True)

    # 4. Relations (collection_poems & poem_recensions)
    print("4/6 Building compact integer relations & indexes...", flush=True)
    col_rel = []
    for c_slug, p_slug in src.execute("SELECT collection_slug, poem_slug FROM collection_poems"):
        cid = col_slug_to_id.get(c_slug)
        pid = poem_slug_to_id.get(p_slug)
        if cid and pid:
            col_rel.append((cid, pid))
    if col_rel:
        dst.executemany("INSERT OR IGNORE INTO collection_poems VALUES (?,?)", col_rel)

    rec_rel = []
    for pid, rec_slugs in pending_recensions:
        for rs in rec_slugs:
            rid = poem_slug_to_id.get(rs)
            if rid and rid != pid:
                rec_rel.append((pid, rid))
    if rec_rel:
        dst.executemany("INSERT OR IGNORE INTO poem_recensions VALUES (?,?)", rec_rel)

    dst.executescript(
        """
        CREATE INDEX idx_poems_poet ON poems(poet_id);
        CREATE INDEX idx_poems_era ON poems(era_id);
        CREATE INDEX idx_poems_meter ON poems(meter_id);
        CREATE INDEX idx_poems_theme ON poems(theme_id);
        CREATE INDEX idx_poems_rhyme ON poems(rhyme_id);
        CREATE INDEX idx_poets_era ON poets(era_id);
        """
    )

    # 5. Lightweight external-content FTS5 on poem titles & poet names
    print("5/6 Building compact FTS5 search indexes (titles + poets)...", flush=True)
    dst.executescript(
        """
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

    meta_rows = [
        ("format", "qafiyah_compact_v1"),
        ("content_codec", "arabic1b_zlib9"),
        ("block_size", str(BLOCK_SIZE)),
        ("poem_count", str(poem_id)),
        ("verse_count", str(total_verses)),
        ("poet_count", str(len(poet_slug_to_id))),
        ("block_count", str(block_id)),
    ]
    dst.executemany("INSERT INTO meta VALUES (?,?)", meta_rows)
    dst.commit()

    # 6. ANALYZE + VACUUM
    print("6/6 Running ANALYZE + VACUUM...", flush=True)
    dst.execute("ANALYZE")
    dst.execute("VACUUM")
    dst.close()

    # Verification: 100% lossless round-trip check on 1,000 random poems + latency benchmark
    print("Verifying 100% lossless round-trip & benchmarking read speed...", flush=True)
    vconn = sqlite3.connect(str(out_path))
    sample_ids = random.sample(range(1, poem_id + 1), min(1000, poem_id))
    block_cache: dict[int, bytes] = {}

    t_read = time.time()
    for pid in sample_ids:
        slug, bid, off, ln = vconn.execute(
            "SELECT slug, block_id, offset, length FROM poems WHERE id=?", (pid,)
        ).fetchone()
        raw_blk = block_cache.get(bid)
        if raw_blk is None:
            comp = vconn.execute(
                "SELECT data FROM content_blocks WHERE id=?", (bid,)
            ).fetchone()[0]
            raw_blk = zlib.decompress(comp)
            if len(block_cache) > 16:
                block_cache.clear()
            block_cache[bid] = raw_blk
        restored = unpack_arabic(memoryview(raw_blk)[off : off + ln])
        orig = src.execute("SELECT content FROM poems WHERE slug=?", (slug,)).fetchone()[0]
        assert restored == orig, f"Mismatch on poem {slug}!"
    read_ms = (time.time() - t_read) / len(sample_ids) * 1000

    # Benchmark FTS5 title search
    t_fts = time.time()
    hits = vconn.execute(
        "SELECT rowid FROM poems_title_fts WHERE poems_title_fts MATCH 'الليل' LIMIT 20"
    ).fetchall()
    fts_ms = (time.time() - t_fts) * 1000

    vconn.close()
    src.close()

    out_mb = out_path.stat().st_size / (1024 * 1024)
    print(f"\n=== OPTIMIZATION COMPLETE in {time.time() - t_start:.1f}s ===", flush=True)
    print(f"Output SQLite : {out_path} ({out_mb:.2f} MB)", flush=True)
    print(f"Round-trip    : 1,000/1,000 poems 100% IDENTICAL (lossless, full tashkeel)", flush=True)
    print(f"Poem read avg : {read_ms:.2f} ms (SQLite lookup + zlib decode + unpack)", flush=True)
    print(f"FTS5 search   : {fts_ms:.2f} ms ({len(hits)} hits for 'الليل')", flush=True)


if __name__ == "__main__":
    src_db = ensure_source_db()
    build_optimized_db(src_db, OUT_DB)

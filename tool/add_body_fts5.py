#!/usr/bin/env python3
"""
Builds a compact, ultra-fast full-body FTS5 index (poems_body_fts with detail=none)
across ALL 338,134 poems & 5,626,336 verses + composite sorting indexes,
then optimizes, vacuums, verifies full-verse search, and gzips for release.
"""
import gzip
import os
import re
import sqlite3
import time
import zlib

SRC_GZ = "qafiyah_db/bayt_qafiyah_merged.db.gz"
OUT_DB = "qafiyah_db/bayt_qafiyah_merged.db"
OUT_GZ = "qafiyah_db/bayt_qafiyah_merged.db.gz"
TMP_GZ = "qafiyah_db/bayt_qafiyah_merged_new.db.gz"

# Match Dart ArabicNormalizer.normalize() 100% EXACTLY (preserving ؤ and ئ, stripping tashkeel/tatweel/zero-width marks)
_DIACRITICS_RE = re.compile(
    r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]"
)
_NON_ARABIC_RE = re.compile(r"[^\u0621-\u064A0-9\s]+")
_MULTI_SPACE_RE = re.compile(r"\s+")
_TRANS = str.maketrans({
    "أ": "ا",
    "إ": "ا",
    "آ": "ا",
    "ٱ": "ا",
    "ى": "ي",
    "ة": "ه",
})


def normalize_ar(text: str) -> str:
    if not text:
        return ""
    s = _DIACRITICS_RE.sub("", text)
    s = s.translate(_TRANS)
    s = _NON_ARABIC_RE.sub(" ", s)
    return _MULTI_SPACE_RE.sub(" ", s).strip()


def unpack_arabic(buf: bytes) -> str:
    out = []
    i = 0
    n = len(buf)
    while i < n:
        b = buf[i]
        if b < 0x7F:
            out.append(chr(b))
            i += 1
        elif b >= 0x80:
            out.append(chr(0x0600 + (b & 0x7F)))
            i += 1
        else:
            ln = buf[i + 1]
            out.append(buf[i + 2 : i + 2 + ln].decode("utf-8", "ignore"))
            i += 2 + ln
    return "".join(out)


def main():
    t_start = time.perf_counter()
    print(f"1. Decompressing {SRC_GZ} -> {OUT_DB} ...")
    with gzip.open(SRC_GZ, "rb") as fin, open(OUT_DB, "wb") as fout:
        while True:
            chunk = fin.read(4 * 1024 * 1024)
            if not chunk:
                break
            fout.write(chunk)
    print(f"   Base DB size: {os.path.getsize(OUT_DB) / 1048576:.2f} MB")

    con = sqlite3.connect(OUT_DB)
    con.execute("PRAGMA journal_mode = OFF")
    con.execute("PRAGMA synchronous = OFF")
    con.execute("PRAGMA cache_size = -131072")  # 128 MB cache
    con.execute("PRAGMA temp_store = MEMORY")

    # Drop existing poems_body_fts if re-running
    con.execute("DROP TABLE IF EXISTS poems_body_fts")
    con.execute(
        """
        CREATE VIRTUAL TABLE poems_body_fts USING fts5(
            body_norm,
            content='',
            detail=none,
            tokenize='unicode61'
        )
        """
    )

    print("2. Indexing all 338,134 poems (titles + 5.62M verses) into poems_body_fts (detail=none) ...")
    # Iterate block-by-block so each content_block is decompressed ONCE!
    blocks = con.execute("SELECT id, data FROM content_blocks ORDER BY id").fetchall()
    poems_by_block = {}
    for pid, title, bid, off, length in con.execute(
        "SELECT id, title, block_id, offset, length FROM poems"
    ):
        poems_by_block.setdefault(bid, []).append((pid, title, off, length))

    total_indexed = 0
    batch = []
    con.execute("BEGIN")
    for idx, (bid, blob) in enumerate(blocks, 1):
        plist = poems_by_block.get(bid)
        if not plist:
            continue
        raw = zlib.decompress(blob)
        for pid, title, off, length in plist:
            body = unpack_arabic(raw[off : off + length])
            # Deduplicate repeated words per poem? No, FTS5 detail=none already deduplicates docID per term!
            norm = normalize_ar(f"{title} {body}")
            batch.append((pid, norm))
            total_indexed += 1
        if len(batch) >= 2000:
            con.executemany(
                "INSERT INTO poems_body_fts(rowid, body_norm) VALUES (?, ?)",
                batch,
            )
            batch.clear()
        if idx % 200 == 0:
            print(f"   Processed {idx}/{len(blocks)} blocks ({total_indexed:,} poems) in {time.perf_counter()-t_start:.1f}s")

    if batch:
        con.executemany(
            "INSERT INTO poems_body_fts(rowid, body_norm) VALUES (?, ?)",
            batch,
        )
        batch.clear()
    con.commit()
    print(f"   Indexed {total_indexed:,} poems in {time.perf_counter()-t_start:.1f}s")

    print("3. Optimizing FTS5 indexes & adding composite sorting indexes ...")
    con.execute("INSERT INTO poems_body_fts(poems_body_fts) VALUES('optimize')")
    con.execute("INSERT INTO poems_title_fts(poems_title_fts) VALUES('optimize')")
    con.execute("INSERT INTO poets_fts(poets_fts) VALUES('optimize')")

    con.execute(
        "CREATE INDEX IF NOT EXISTS idx_poets_sort_poems ON poets(poem_count DESC, name_norm ASC)"
    )
    con.execute(
        "CREATE INDEX IF NOT EXISTS idx_poets_era_sort ON poets(era_id, poem_count DESC, name_norm ASC)"
    )
    con.execute(
        "CREATE INDEX IF NOT EXISTS idx_poems_theme_sort ON poems(theme_id, is_free_verse ASC, has_diacritics DESC, verse_count DESC)"
    )
    con.execute("ANALYZE")
    con.commit()

    print("4. Vacuuming & verifying integrity ...")
    con.execute("VACUUM")
    qc = con.execute("PRAGMA quick_check").fetchone()[0]
    print(f"   PRAGMA quick_check = {qc}")
    assert qc == "ok", f"Integrity check failed: {qc}"

    # Verify full-verse search across ALL tricky Arabic hamza/tashkeel/phrase scenarios!
    for label, q in [
        ("سئمت تكاليف", "سئمت* AND تكاليف*"),
        ("فؤاد", "فؤاد*"),
        ("مؤمن", "مؤمن*"),
        ("لؤلؤ", "لؤلؤ*"),
        ("ذئب", "ذئب*"),
        ("سؤال", "سؤال*"),
        ("طائر", "طائر*"),
        ("أيوب صبري", "ايوب* AND صبري*"),
        ("على قدر أهل العزم", "علي AND قدر AND اهل AND العزم"),
        ("قفا نبك", "قفا AND نبك"),
    ]:
        t0 = time.perf_counter()
        rows = con.execute(
            """
            SELECT p.id, pt.name, p.title
            FROM poems_body_fts f
            JOIN poems p ON p.id = f.rowid
            JOIN poets pt ON pt.id = p.poet_id
            WHERE poems_body_fts MATCH ?
            LIMIT 10
            """,
            (q,),
        ).fetchall()
        dt = (time.perf_counter() - t0) * 1000
        assert len(rows) > 0, f"ZERO hits for {label} ({q})!"
        print(f"   Search [{label}] -> {len(rows)} hits in {dt:.2f} ms | sample: {rows[:2]}")

    con.close()
    db_mb = os.path.getsize(OUT_DB) / 1048576
    print(f"   Final DB size: {db_mb:.2f} MB")

    print(f"5. Compressing {OUT_DB} -> {TMP_GZ} (gzip level 6) ...")
    t_gz = time.perf_counter()
    with open(OUT_DB, "rb") as fin, gzip.open(TMP_GZ, "wb", compresslevel=6) as fout:
        while True:
            chunk = fin.read(4 * 1024 * 1024)
            if not chunk:
                break
            fout.write(chunk)
    os.replace(TMP_GZ, OUT_GZ)
    gz_mb = os.path.getsize(OUT_GZ) / 1048576
    print(f"   Final .db.gz size: {gz_mb:.2f} MB (compressed in {time.perf_counter()-t_gz:.1f}s)")
    print(f"DONE in {time.perf_counter()-t_start:.1f}s!")


if __name__ == "__main__":
    main()

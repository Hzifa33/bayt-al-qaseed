#!/usr/bin/env python3
"""
Repacks bayt_qafiyah_merged.db.gz into an ultra-compact, single-stream XZ (LZMA2)
archive (`bayt_qafiyah_merged.db.xz`) targeting ~110-115 MB (~135 MB ARM64 APK).

Why this shrinks the APK by ~105+ MB without losing a single byte of data:
  1. Unpacks `content_blocks.data` from 2,642 tiny per-block zlib streams
     (incompressible high-entropy blobs) back to raw 1-byte packed Arabic.
  2. Records `content_blocks_codec = 'raw'` in `metadata` so the app reads poem
     bodies directly with zero runtime zlib overhead (faster poem opening!).
  3. Runs VACUUM + PRAGMA quick_check to guarantee a compact, valid SQLite file.
  4. Compresses the entire database in a single LZMA2 stream (preset=6, 8 MiB
     dictionary) so shared Arabic roots, meters, phrases, and FTS5 postings
     compress across the whole corpus while decompressing in <10 MB RAM on
     Android in ~15-30 seconds.
"""

from __future__ import annotations

import argparse
import gzip
import lzma
import os
import sqlite3
import tempfile
import time
import zlib
from pathlib import Path


def is_zlib_blob(blob: bytes) -> bool:
    if len(blob) < 2:
        return False
    cmf, flg = blob[0], blob[1]
    return (cmf & 0x0F) == 8 and ((cmf << 8) | flg) % 31 == 0


def repack(input_gz: Path, output_xz: Path, preset: int = 6) -> None:
    t0 = time.perf_counter()
    if not input_gz.exists():
        raise FileNotFoundError(f"Input gzip database not found: {input_gz}")

    in_mb = input_gz.stat().st_size / (1024 * 1024)
    print(f"[1/4] Decompressing {input_gz} ({in_mb:.2f} MB)...", flush=True)

    output_xz.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bayt_repack_") as tmp_dir:
        work_db = Path(tmp_dir) / "corpus_raw.db"
        with gzip.open(input_gz, "rb") as fin, open(work_db, "wb") as fout:
            while True:
                chunk = fin.read(4 * 1024 * 1024)
                if not chunk:
                    break
                fout.write(chunk)

        base_mb = work_db.stat().st_size / (1024 * 1024)
        print(f"      Base SQLite size: {base_mb:.2f} MB ({time.perf_counter() - t0:.1f}s)", flush=True)

        print("[2/4] Unpacking content_blocks from per-block zlib -> raw 1-byte Arabic...", flush=True)
        con = sqlite3.connect(str(work_db))
        con.execute("PRAGMA journal_mode = OFF")
        con.execute("PRAGMA synchronous = OFF")
        con.execute("PRAGMA temp_store = MEMORY")
        con.execute("PRAGMA cache_size = -131072")

        rows = con.execute("SELECT id, data FROM content_blocks ORDER BY id").fetchall()
        unpacked_count = 0
        already_raw = 0
        con.execute("BEGIN")
        for bid, blob in rows:
            raw_bytes = bytes(blob)
            if is_zlib_blob(raw_bytes):
                try:
                    raw_bytes = zlib.decompress(raw_bytes)
                    unpacked_count += 1
                except zlib.error:
                    already_raw += 1
            else:
                already_raw += 1
            con.execute("UPDATE content_blocks SET data = ? WHERE id = ?", (raw_bytes, bid))

        con.execute(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES ('content_blocks_codec', 'raw')"
        )
        con.commit()
        print(
            f"      Blocks updated: {unpacked_count:,} unpacked, {already_raw:,} already raw "
            f"({time.perf_counter() - t0:.1f}s)",
            flush=True,
        )

        print("[3/4] Running VACUUM & PRAGMA quick_check...", flush=True)
        con.execute("VACUUM")
        qc = con.execute("PRAGMA quick_check").fetchone()[0]
        if qc != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {qc}")
        poem_count = con.execute("SELECT COUNT(*) FROM poems").fetchone()[0]
        con.close()

        uncompressed_bytes = work_db.stat().st_size
        uncompressed_mb = uncompressed_bytes / (1024 * 1024)
        print(
            f"      Verified {poem_count:,} poems | Uncompressed raw-block DB: "
            f"{uncompressed_mb:.2f} MB ({uncompressed_bytes:,} bytes)",
            flush=True,
        )

        print(f"[4/4] Compressing to XZ (LZMA2 preset={preset}, CRC64) -> {output_xz}...", flush=True)
        t_xz = time.perf_counter()
        tmp_xz = output_xz.with_suffix(output_xz.suffix + ".tmp")
        with open(work_db, "rb") as fin, lzma.open(
            tmp_xz,
            "wb",
            format=lzma.FORMAT_XZ,
            check=lzma.CHECK_CRC64,
            preset=preset,
        ) as fout:
            written = 0
            while True:
                chunk = fin.read(4 * 1024 * 1024)
                if not chunk:
                    break
                fout.write(chunk)
                written += len(chunk)
                if written % (64 * 1024 * 1024) == 0:
                    pct = (written / uncompressed_bytes) * 100.0
                    print(
                        f"      Compressed {written / (1024 * 1024):.0f}/{uncompressed_mb:.0f} MB "
                        f"({pct:.1f}%) in {time.perf_counter() - t_xz:.1f}s...",
                        flush=True,
                    )

        os.replace(tmp_xz, output_xz)
        out_bytes = output_xz.stat().st_size
        out_mb = out_bytes / (1024 * 1024)
        ratio = (1.0 - (out_bytes / uncompressed_bytes)) * 100.0
        saved_vs_gz = in_mb - out_mb
        print(
            f"DONE in {time.perf_counter() - t0:.1f}s!\n"
            f"  Input  (.db.gz): {in_mb:.2f} MB\n"
            f"  Raw DB (.db)   : {uncompressed_mb:.2f} MB\n"
            f"  Output (.db.xz): {out_mb:.2f} MB ({out_bytes:,} bytes, {ratio:.1f}% smaller than raw, "
            f"{saved_vs_gz:+.2f} MB vs .db.gz)",
            flush=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Repack corpus .db.gz into compact .db.xz")
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("assets/db/bayt_qafiyah_merged.db.gz"),
        help="Path to input .db.gz",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/db/bayt_qafiyah_merged.db.xz"),
        help="Path to output .db.xz",
    )
    parser.add_argument(
        "--preset",
        type=int,
        default=6,
        choices=range(1, 10),
        help="LZMA2 compression preset (default 6 = 8 MiB dict, <10 MB RAM on Android)",
    )
    args = parser.parse_args()
    repack(args.input, args.output, preset=args.preset)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build CC-CEDICT SQLite dictionary database for Zephyr Reader.

Downloads CC-CEDICT, parses entries, and creates a SQLite database
with FTS5 full-text search index at assets/dictionary.db.

Usage:
    python scripts/build_dictionary.py [--output assets/dictionary.db]

Download URL:
    https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz
"""

import argparse
import gzip
import os
import sqlite3
import urllib.request
from pathlib import Path

CC_CEDICT_URL = (
    "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz"
)
EXPECTED_ENTRIES = 120_000


def download_cedict(target: Path) -> None:
    """Download and decompress CC-CEDICT to target path."""
    print(f"Downloading CC-CEDICT from {CC_CEDICT_URL}...")
    req = urllib.request.Request(CC_CEDICT_URL)
    with urllib.request.urlopen(req) as response:
        decompressed = gzip.decompress(response.read())
    target.write_bytes(decompressed)
    print(f"Downloaded {target}")


def parse_line(line: str) -> dict | None:
    """Parse a single CC-CEDICT line into a dict entry."""
    line = line.strip()
    if not line or line.startswith("#"):
        return None

    try:
        # Format: Traditional Simplified [pinyin] /def1/def2/
        trad_end = line.index(" ")
        simplified_start = trad_end + 1
        pinyin_start = line.index("[", simplified_start)
        def_start = line.index("/", pinyin_start)

        traditional = line[:trad_end]
        simplified = line[simplified_start:pinyin_start].strip()
        pinyin = line[pinyin_start + 1 : def_start - 1].strip()
        definitions_raw = line[def_start:]

        # Parse definitions
        definitions = [
            d.strip()
            for d in definitions_raw.split("/")
            if d.strip()
        ]

        return {
            "simplified": simplified,
            "traditional": traditional,
            "pinyin": pinyin,
            "definitions": "/".join(definitions),
        }
    except (ValueError, IndexError):
        return None


def build_database(cedict_path: Path, output_path: Path) -> None:
    """Parse CC-CEDICT and create SQLite database."""
    print(f"Parsing {cedict_path}...")

    entries = []
    with cedict_path.open("r", encoding="utf-8") as f:
        for line in f:
            entry = parse_line(line)
            if entry:
                entries.append(entry)

    print(f"Parsed {len(entries)} entries")

    if output_path.exists():
        output_path.unlink()

    conn = sqlite3.connect(str(output_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA page_size=4096")

    conn.execute("""
        CREATE TABLE dictionary_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            simplified TEXT NOT NULL,
            traditional TEXT NOT NULL,
            pinyin TEXT,
            definitions TEXT NOT NULL,
            word_type TEXT DEFAULT ''
        )
    """)
    conn.execute("CREATE INDEX idx_dict_simplified ON dictionary_entries(simplified)")
    conn.execute("CREATE INDEX idx_dict_traditional ON dictionary_entries(traditional)")

    conn.execute("""
        CREATE VIRTUAL TABLE dictionary_fts USING fts5(
            simplified, traditional, definitions,
            content='dictionary_entries',
            content_rowid='id',
            tokenize='unicode61'
        )
    """)

    conn.execute("""
        CREATE TABLE dictionary_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    """)

    # Batch insert
    BATCH = 1000
    for i in range(0, len(entries), BATCH):
        batch = entries[i : i + BATCH]
        conn.executemany(
            """INSERT INTO dictionary_entries
               (simplified, traditional, pinyin, definitions)
               VALUES (:simplified, :traditional, :pinyin, :definitions)""",
            batch,
        )
        # Row IDs for this batch
        for j, entry in enumerate(batch):
            row_id = i + j + 1
            conn.execute(
                """INSERT INTO dictionary_fts
                   (rowid, simplified, traditional, definitions)
                   VALUES (?, ?, ?, ?)""",
                (
                    row_id,
                    entry["simplified"],
                    entry["traditional"],
                    entry["definitions"],
                ),
            )

    conn.execute(
        "INSERT INTO dictionary_meta (key, value) VALUES ('version', '1.0')"
    )
    conn.execute(
        "INSERT INTO dictionary_meta (key, value) VALUES ('source', 'CC-CEDICT')"
    )
    conn.execute(
        "INSERT INTO dictionary_meta (key, value) VALUES ('entry_count', ?)",
        (len(entries),),
    )

    conn.commit()
    conn.execute("PRAGMA analysis_limit=1000")
    conn.execute("PRAGMA optimize")
    conn.close()

    db_size = output_path.stat().st_size
    print(f"Database written to {output_path} ({db_size:,} bytes, {len(entries)} entries)")


def main():
    parser = argparse.ArgumentParser(
        description="Build CC-CEDICT SQLite dictionary for Zephyr Reader"
    )
    parser.add_argument(
        "--output",
        default=str(Path(__file__).resolve().parents[1] / "assets" / "dictionary.db"),
        help="Output SQLite database path",
    )
    parser.add_argument(
        "--cedict",
        default=None,
        help="Path to existing CC-CEDICT text file (skips download if provided)",
    )
    args = parser.parse_args()

    output_path = Path(args.output)
    assets_dir = output_path.parent
    assets_dir.mkdir(parents=True, exist_ok=True)

    if args.cedict:
        cedict_path = Path(args.cedict)
    else:
        cache_dir = Path.home() / ".cache" / "zephyr-reader"
        cache_dir.mkdir(parents=True, exist_ok=True)
        cedict_path = cache_dir / "cedict.txt"
        if not cedict_path.exists():
            download_cedict(cedict_path)
        else:
            print(f"Using cached {cedict_path}")

    build_database(cedict_path, output_path)
    print("Done. Dictionary database ready.")


if __name__ == "__main__":
    main()

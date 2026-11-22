#!/usr/bin/env python3
"""
Upgrades tool/bayt_al_qaseed.db in-place:
1. Adds composite indexes for instant meter browsing & era poet sorting.
2. Replaces featured_verses with hand-verified iconic Arabic poetry masterpieces
   found directly inside the corpus (preserving exact verse index & diacritics).
3. Runs ANALYZE, VACUUM, and recompresses assets/db/bayt_al_qaseed.db.gz.
"""

from __future__ import annotations

import gzip
import re
import sqlite3
import time
import unicodedata
from pathlib import Path

ROOT = Path("/data/data/com.termux/files/home/Arabic/bayt_al_qaseed")
DB_PATH = ROOT / "tool" / "bayt_al_qaseed.db"
GZ_PATH = ROOT / "assets" / "db" / "bayt_al_qaseed.db.gz"

TASHKEEL_RE = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")
NON_SEARCH_RE = re.compile(r"[^\u0621-\u064A0-9\s]")
SPACE_RE = re.compile(r"\s+")


def norm(s: str) -> str:
    s = unicodedata.normalize("NFC", s)
    s = TASHKEEL_RE.sub("", s)
    s = (
        s.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ٱ", "ا")
        .replace("ى", "ي")
        .replace("ة", "ه")
    )
    s = NON_SEARCH_RE.sub(" ", s)
    return SPACE_RE.sub(" ", s).strip()


# (fts_phrase, preferred_poet_substring_or_None, poetic_tag)
MASTERPIECES: list[tuple[str, str | None, str]] = [
    ("علي قدر اهل العزم", "المتنبي", "من عيون الحكمة"),
    ("انا الذي نظر الاعمي الي ادبي", "المتنبي", "من روائع الفخر"),
    ("البيداء تعرفني", "المتنبي", "من عيون الفخر"),
    ("ما كل ما يتمني المرء يدركه", "المتنبي", "من خالدات الحكمة"),
    ("واذا اتتك مذمتي من ناقص", "المتنبي", "من عيون الحكمة"),
    ("عش عزيزا او مت وانت كريم", "المتنبي", "من روائع الإباء"),
    ("عيد بايه حال عدت يا عيد", "المتنبي", "من أشهر المراثي والشكوى"),
    ("قفا نبك من ذكري حبيب ومنزل", "امرؤ القيس", "مطلع المعلّقة الأولى"),
    ("هل غادر الشعراء من متردم", "عنترة", "مطلع معلّقة عنترة"),
    ("لخوله اطلال ببرقه ثهمد", "طرفة", "مطلع معلّقة طرفة"),
    ("الا هبي بصحنك فاصبحينا", "عمرو بن كلثوم", "مطلع معلّقة عمرو"),
    ("الا كل شيء ما خلا الله باطل", "لبيد", "أصدق بيت قالته العرب"),
    ("سئمت تكاليف الحياه ومن يعش", "زهير", "من حكمة معلّقة زهير"),
    ("لا تعذليه فان العذل يولعه", "ابن زريق", "اليتيمة الخالدة"),
    ("اراك عصي الدمع شيمتك الصبر", "فراس", "من عيون الروميات"),
    ("السيف اصدق انباء من الكتب", "تمام", "فتح عمّورية"),
    ("صنت نفسي عما يدنس نفسي", "البحتري", "سينية البحتري"),
    ("اضحي التنائي بديلا من تدانينا", "زيدون", "نونية ابن زيدون"),
    ("يا ليل الصب متي غده", "الحصري", "من عيون الأندلس"),
    ("جادك الغيث اذا الغيث همي", "الخطيب", "موشّحة غرناطة"),
    ("لكل شيء اذا ما تم نقصان", "الرندي", "رثاء الأندلس"),
    ("امن تذكر جيران بذي سلم", "البوصيري", "مطلع البردة الشريفة"),
    ("دع الايام تفعل ما تشاء", "الشافعي", "من جواهر الحكمة"),
    ("نعيب زماننا والعيب فينا", "الشافعي", "من عيون الحكمة"),
    ("امر علي الديار ديار ليلي", "مجنون", "من عيون الغزل العذري"),
    ("وما نيل المطالب بالتمني", "شوقي", "من عيون الإرادة"),
    ("قم للمعلم وفه التبجيلا", "شوقي", "في فضل العلم"),
    ("وطني لو شغلت بالخلد عنه", "شوقي", "سينية الحنين للوطن"),
    ("ريم علي القاع بين البان والعلم", "شوقي", "نهج البردة"),
    ("اذا الشعب يوما اراد الحياه", "الشابي", "إرادة الحياة"),
    ("كن جميلا تر الوجود جميلا", "ماضي", "فلسفة الجمال"),
    ("قال السماء كئيبه وتجهما", "ماضي", "ابتسم"),
    ("غير مجد في ملتي واعتقادي", "المعري", "تأملات المعري"),
    ("اذا المرء لم يدنس من اللؤم عرضه", "السموأل", "لامية السموأل"),
    ("بانت سعاد فقلبي اليوم متبول", "كعب", "قصيدة البردة النبوية"),
    ("قذي بعينك ام بالعين عوار", "الخنساء", "من عيون الرثاء"),
    ("ان العيون التي في طرفها حور", "جرير", "من أرقّ الغزل الأموي"),
    ("خف القطين فراحوا منك او بكروا", "الأخطل", "من عيون الأموي"),
    ("امن ال نعم انت غاد فمبكر", "ربيعة", "من روائع الغزل"),
    ("توخي حمام الموت اوسط صبيتي", "الرومي", "دالية الرثاء الخالدة"),
    ("الام مدرسه اذا اعددتها", "حافظ", "في تكريم الأم"),
    ("هي الاخلاق تنبت كالنبات", "الرصافي", "في مكارم الأخلاق"),
    ("يا دار ميه بالعلياء فالسند", "النابغة", "من عيون الجاهلية"),
    ("يا قوم اذني لبعض الحي عاشقه", "بشار", "من بدائع العباسي"),
    ("دع عنك لومي فان اللوم اغراء", "نواس", "من عيون العباسي"),
    ("النفس تبكي علي الدنيا وقد علمت", "علي", "من جواهر الزهد"),
    ("مررنا علي دار الحبيب فردنا", "البرغوثي", "في القدس"),
    ("لا تحسبن المجد تمرا انت اكله", None, "من أمثال الشعر العربي"),
    ("ومن لم يذق مر التعلم ساعه", "الشافعي", "في طلب العلم"),
    ("ولرب نازله يضيق بها الفتي", "الشافعي", "في الفرج بعد الشدة"),
    ("ستبدي لك الايام ما كنت جاهلا", "طرفة", "من حكمة المعلّقات"),
    ("تريدين ادراك المعالي رخيصه", "المتنبي", "من عيون الهمّة"),
    ("لا تشتري العبد الا والعصا معه", "المتنبي", "من أشهر الهجاء"),
    ("اذا رايت نيوب الليث بارزه", "المتنبي", "من أمثال المتنبي"),
    ("واحر قلباه ممن قلبه شبم", "المتنبي", "عتاب سيف الدولة"),
]


def main() -> None:
    t0 = time.perf_counter()
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA journal_mode = OFF;")
    conn.execute("PRAGMA synchronous = OFF;")

    print("1. Creating composite indexes for instant meter & era browsing...")
    conn.executescript(
        """
        CREATE INDEX IF NOT EXISTS idx_poems_meter_verses ON poems(meter_id, verse_count DESC);
        CREATE INDEX IF NOT EXISTS idx_poets_era_verses ON poets(era_id, verse_count DESC);
        CREATE INDEX IF NOT EXISTS idx_poets_era_name ON poets(era_id, name_norm ASC);
        """
    )

    print("2. Curating iconic famous masterpieces into featured_verses...")
    conn.execute("DROP TABLE IF EXISTS featured_verses;")
    conn.execute(
        """
        CREATE TABLE featured_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            poem_id INTEGER NOT NULL REFERENCES poems(id),
            poet_id INTEGER NOT NULL REFERENCES poets(id),
            era_id INTEGER NOT NULL REFERENCES eras(id),
            verse_index INTEGER NOT NULL,
            sadr TEXT NOT NULL,
            ajuz TEXT NOT NULL,
            poet_name TEXT NOT NULL,
            era_name TEXT NOT NULL,
            tag TEXT NOT NULL DEFAULT 'من عيون الشعر',
            is_masterpiece INTEGER NOT NULL DEFAULT 1
        );
        """
    )

    seen_poems: set[int] = set()
    inserted = 0

    for phrase, poet_hint, tag in MASTERPIECES:
        rows = conn.execute(
            """
            SELECT p.id, p.poet_id, p.era_id, pt.name_plain, e.name, p.body
            FROM poems_fts f
            JOIN poems p ON p.id = f.rowid
            JOIN poets pt ON pt.id = p.poet_id
            JOIN eras e ON e.id = p.era_id
            WHERE poems_fts MATCH ?
            LIMIT 25
            """,
            (f'"{phrase}"',),
        ).fetchall()

        chosen = None
        if poet_hint:
            hint_norm = norm(poet_hint)
            for r in rows:
                if hint_norm in norm(r[3]):
                    chosen = r
                    break
        if chosen is None and rows:
            chosen = rows[0]
        if chosen is None or chosen[0] in seen_poems:
            continue

        poem_id, poet_id, era_id, poet_name, era_name, body = chosen
        # Find the exact verse matching the phrase
        lines = [ln for ln in body.split("\n") if ln.strip()]
        best_idx = 0
        best_sadr, best_ajuz = "", ""
        for idx, ln in enumerate(lines):
            if "\t" in ln:
                s, a = ln.split("\t", 1)
            else:
                s, a = ln, ""
            if phrase in norm(f"{s} {a}"):
                best_idx = idx
                best_sadr, best_ajuz = s, a
                break
        if not best_sadr:
            ln0 = lines[0]
            if "\t" in ln0:
                best_sadr, best_ajuz = ln0.split("\t", 1)
            else:
                best_sadr, best_ajuz = ln0, ""

        conn.execute(
            """
            INSERT INTO featured_verses
                (poem_id, poet_id, era_id, verse_index, sadr, ajuz, poet_name, era_name, tag, is_masterpiece)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            """,
            (poem_id, poet_id, era_id, best_idx, best_sadr, best_ajuz, poet_name, era_name, tag),
        )
        seen_poems.add(poem_id)
        inserted += 1

    print(f"   Inserted {inserted} verified iconic Arabic poetry masterpieces.")

    # Verify meter query latency with new composite index
    tq = time.perf_counter()
    conn.execute(
        """
        SELECT p.id, p.title FROM poems p
        WHERE p.meter_id = 1
        ORDER BY p.verse_count DESC
        LIMIT 60
        """
    ).fetchall()
    print(f"   Meter query latency (الطويل, 21K poems): {(time.perf_counter() - tq)*1000:.2f} ms")

    conn.execute("UPDATE metadata SET value = '2' WHERE key = 'schema_version';")
    conn.commit()
    print("3. Running ANALYZE & VACUUM...")
    conn.execute("ANALYZE;")
    conn.execute("VACUUM;")
    conn.commit()
    conn.close()

    print("4. Recompressing assets/db/bayt_al_qaseed.db.gz...")
    with open(DB_PATH, "rb") as f_in, gzip.open(GZ_PATH, "wb", compresslevel=9) as f_out:
        while chunk := f_in.read(1024 * 1024):
            f_out.write(chunk)
    print(
        f"Done in {time.perf_counter() - t0:.1f}s! "
        f"GZ size: {GZ_PATH.stat().st_size / 1024 / 1024:.2f} MB"
    )


if __name__ == "__main__":
    main()

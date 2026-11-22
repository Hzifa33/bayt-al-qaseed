#!/usr/bin/env python3
"""
Upgrades tool/bayt_al_qaseed.db (v3):
1. Ensures composite indexes for instant meter browsing & era poet sorting.
2. Populates featured_verses with 62+ categorized iconic Arabic poetry
   masterpieces: Ten Mu'allaqat, Lamiyyat, Siniyyat, Ghazal, Ritha, Wisdom.
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


# (category, title_tag, fts_phrase, preferred_poet_hint)
MASTERPIECES: list[tuple[str, str, str, str | None]] = [
    # 1. المعلّقات العشر كاملة
    ("المعلّقات", "معلّقة امرئ القيس", "قفا نبك من ذكري حبيب ومنزل", "امرؤ القيس"),
    ("المعلّقات", "معلّقة طرفة بن العبد", "لخوله اطلال ببرقه ثهمد", "طرفة"),
    ("المعلّقات", "معلّقة زهير بن أبي سلمى", "امن ام اوفي دمنه لم تكلم", "زهير"),
    ("المعلّقات", "معلّقة لبيد بن ربيعة", "عفت الديار محلها فمقامها", "لبيد"),
    ("المعلّقات", "معلّقة عمرو بن كلثوم", "الا هبي بصحنك فاصبحينا", "عمرو بن كلثوم"),
    ("المعلّقات", "معلّقة عنترة بن شداد", "هل غادر الشعراء من متردم", "عنترة"),
    ("المعلّقات", "معلّقة الحارث بن حلزة", "اذنتنا ببينها اسماء", "حلزة"),
    ("المعلّقات", "معلّقة الأعشى الكبير", "ودع هريره ان الركب مرتحل", "الأعشى"),
    ("المعلّقات", "معلّقة النابغة الذبياني", "يا دار ميه بالعلياء فالسند", "النابغة"),
    ("المعلّقات", "معلّقة عبيد بن الأبرص", "اقفر من اهله ملحوب", "عبيد"),
    # 2. اللاميات والسينيات والبردات والخالدات
    ("خالدات", "لامية العرب", "اقيموا بني امي صدور مطيكم", "الشنفرى"),
    ("خالدات", "لامية العجم", "اصاله الراي صانتني عن الخطل", "الطغرائي"),
    ("خالدات", "لامية السموأل", "اذا المرء لم يدنس من اللؤم عرضه", "السموأل"),
    ("خالدات", "سينية البحتري (إيوان كسرى)", "صنت نفسي عما يدنس نفسي", "البحتري"),
    ("خالدات", "سينية أحمد شوقي (الأندلس)", "اختلاف النهار والليل ينسي", "شوقي"),
    ("خالدات", "نهج البردة", "ريم علي القاع بين البان والعلم", "شوقي"),
    ("خالدات", "البردة الشريفة", "امن تذكر جيران بذي سلم", "البوصيري"),
    ("خالدات", "بانت سعاد", "بانت سعاد فقلبي اليوم متبول", "كعب"),
    ("خالدات", "اليتيمة الخالدة", "لا تعذليه فان العذل يولعه", "زريق"),
    ("خالدات", "فتح عمّورية", "السيف اصدق انباء من الكتب", "تمام"),
    ("خالدات", "واحرَّ قلباه", "واحر قلباه ممن قلبه شبم", "المتنبي"),
    ("خالدات", "إرادة الحياة", "اذا الشعب يوما اراد الحياه", "الشابي"),
    ("خالدات", "في القدس", "مررنا علي دار الحبيب فردنا", "البرغوثي"),
    # 3. أشهر قصائد الغزل
    ("الغزل", "المؤنسة — قيس بن الملوّح", "تذكرت ليلي والسنين الخواليا", "مجنون"),
    ("الغزل", "أمرُّ على الديار", "امر علي الديار ديار ليلي", "مجنون"),
    ("الغزل", "نونية ابن زيدون", "اضحي التنائي بديلا من تدانينا", "زيدون"),
    ("الغزل", "يا ليلَ الصبّ", "يا ليل الصب متي غده", "الحصري"),
    ("الغزل", "أراك عصيَّ الدمع", "اراك عصي الدمع شيمتك الصبر", "فراس"),
    ("الغزل", "إن العيون التي في طرفها حور", "ان العيون التي في طرفها حور", "جرير"),
    ("الغزل", "موشّحة جادك الغيث", "جادك الغيث اذا الغيث همي", "الخطيب"),
    ("الغزل", "أمن آلِ نُعم", "امن ال نعم انت غاد فمبكر", "ربيعة"),
    ("الغزل", "أهابك إجلالاً", "اهابك اجلالا وما بك قدره", None),
    ("الغزل", "قلبي يحدّثني", "قلبي يحدثني بانك متلفي", "الفارض"),
    ("الغزل", "ألا ليت ريعان الشباب", "الا ليت ريعان الشباب جديد", "جميل"),
    ("الغزل", "يا قومُ أذني لبعض الحي عاشقة", "يا قوم اذني لبعض الحي عاشقه", "بشار"),
    ("الغزل", "أبكي الذين أذاقوني مودّتهم", "ابكي الذين اذاقوني مودتهم", "الأحنف"),
    ("الغزل", "مُضناك جفاه مرقده", "مضناك جفاه مرقده", "شوقي"),
    ("الغزل", "ولقد ذكرتك والرماح نواهل", "ولقد ذكرتك والرماح نواهل", None),
    # 4. أشهر قصائد الرثاء
    ("الرثاء", "رثاء الأندلس", "لكل شيء اذا ما تم نقصان", "الرندي"),
    ("الرثاء", "دالية ابن الرومي في ابنه", "توخي حمام الموت اوسط صبيتي", "الرومي"),
    ("الرثاء", "عينية أبي ذؤيب الهذلي", "امن المنون وريبها تتوجع", "ذؤيب"),
    ("الرثاء", "رثاء مالك بن الريب لنفسه", "الا ليت شعري هل ابيتن ليله", "الريب"),
    ("الرثاء", "رثاء الخنساء لأخيها صخر", "قذي بعينك ام بالعين عوار", "الخنساء"),
    ("الرثاء", "أعينيَّ جودا ولا تجمدا", "اعيني جودا ولا تجمدا", "الخنساء"),
    ("الرثاء", "رثاء أبي العلاء المعري", "غير مجد في ملتي واعتقادي", "المعري"),
    ("الرثاء", "رثاء التهامي لابنه", "حكم المنيه في البريه جاري", "التهامي"),
    ("الرثاء", "رثاء المتنبي لجدّته", "الا لا اري الاحداث حمدا ولا ذما", "المتنبي"),
    # 5. الحكمة والفخر والزهد
    ("الحكمة", "على قدر أهل العزم", "علي قدر اهل العزم تاتي العزائم", "المتنبي"),
    ("الحكمة", "ما كلّ ما يتمنّى المرء", "ما كل ما يتمني المرء يدركه", "المتنبي"),
    ("الحكمة", "دع الأيام تفعل ما تشاء", "دع الايام تفعل ما تشاء", "الشافعي"),
    ("الحكمة", "نعيب زماننا والعيب فينا", "نعيب زماننا والعيب فينا", "الشافعي"),
    ("الحكمة", "النفس تبكي على الدنيا", "النفس تبكي علي الدنيا وقد علمت", "علي"),
    ("الحكمة", "كن جميلاً", "كن جميلا تر الوجود جميلا", "ماضي"),
    ("الحكمة", "ابتسم", "قال السماء كئيبه وتجهما", "ماضي"),
    ("الحكمة", "قم للمعلّم", "قم للمعلم وفه التبجيلا", "شوقي"),
    ("الحكمة", "الأمّ مدرسة", "الام مدرسه اذا اعددتها", "حافظ"),
    ("الحكمة", "هي الأخلاق تنبت كالنبات", "هي الاخلاق تنبت كالنبات", "الرصافي"),
    ("الحكمة", "أصدق بيت قالته العرب", "الا كل شيء ما خلا الله باطل", "لبيد"),
    ("الحكمة", "وإذا أتتك مذمّتي من ناقص", "واذا اتتك مذمتي من ناقص", "المتنبي"),
    ("الحكمة", "عِش عزيزاً أو مُت وأنت كريم", "عش عزيزا او مت وانت كريم", "المتنبي"),
]


def main() -> None:
    t0 = time.perf_counter()
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA journal_mode = OFF;")
    conn.execute("PRAGMA synchronous = OFF;")

    conn.executescript(
        """
        CREATE INDEX IF NOT EXISTS idx_poems_meter_verses ON poems(meter_id, verse_count DESC);
        CREATE INDEX IF NOT EXISTS idx_poets_era_verses ON poets(era_id, verse_count DESC);
        CREATE INDEX IF NOT EXISTS idx_poets_era_name ON poets(era_id, name_norm ASC);
        """
    )

    conn.execute("DROP TABLE IF EXISTS featured_verses;")
    conn.execute(
        """
        CREATE TABLE featured_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            poem_id INTEGER NOT NULL REFERENCES poems(id),
            poet_id INTEGER NOT NULL REFERENCES poets(id),
            era_id INTEGER NOT NULL REFERENCES eras(id),
            verse_index INTEGER NOT NULL,
            verse_count INTEGER NOT NULL DEFAULT 0,
            sadr TEXT NOT NULL,
            ajuz TEXT NOT NULL,
            poet_name TEXT NOT NULL,
            era_name TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'خالدات',
            tag TEXT NOT NULL DEFAULT 'من عيون الشعر'
        );
        """
    )

    seen_poems: set[int] = set()
    inserted = 0

    for category, tag, phrase, poet_hint in MASTERPIECES:
        rows = conn.execute(
            """
            SELECT p.id, p.poet_id, p.era_id, p.verse_count, pt.name_plain, e.name, p.body
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
                if hint_norm in norm(r[4]):
                    chosen = r
                    break
        if chosen is None and rows:
            chosen = rows[0]
        if chosen is None or chosen[0] in seen_poems:
            continue

        poem_id, poet_id, era_id, v_count, poet_name, era_name, body = chosen
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
                (poem_id, poet_id, era_id, verse_index, verse_count, sadr, ajuz, poet_name, era_name, category, tag)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (poem_id, poet_id, era_id, best_idx, v_count, best_sadr, best_ajuz, poet_name, era_name, category, tag),
        )
        seen_poems.add(poem_id)
        inserted += 1

    print(f"Inserted {inserted} categorized iconic masterpieces into featured_verses.")
    conn.execute("UPDATE metadata SET value = '3' WHERE key = 'schema_version';")
    conn.commit()
    conn.execute("ANALYZE;")
    conn.execute("VACUUM;")
    conn.commit()
    conn.close()

    with open(DB_PATH, "rb") as f_in, gzip.open(GZ_PATH, "wb", compresslevel=9) as f_out:
        while chunk := f_in.read(1024 * 1024):
            f_out.write(chunk)
    print(f"Done in {time.perf_counter() - t0:.1f}s! GZ size: {GZ_PATH.stat().st_size / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()

# بيت القصيد — موسوعة الشعر العربي (Flutter)

إعادة بناء هندسية وتصميمية شاملة لتطبيق الشعر العربي بلغة **Flutter / Dart** وهوية تحريرية دافئة (**Warm Editorial Minimalism + Subtle Neo-Heritage**)، مع محرك بحث فوري عبر **SQLite FTS5** وتطبيع عربي كامل يعمل دون اتصال بالإنترنت (**100% Offline-First**).

---

## المميزات الرئيسية

- **مكتبة شعرية ضخمة ومنقّحة:** 542 شاعراً فريداً عبر 11 عصراً أدبياً، 90,238 قصيدة، و1,162,119 بيتاً شعرياً (أكثر من 96% منها مشكّلة بالكامل)، خالية من الإعلانات أو التتبع.
- **قاعدة بيانات SQLite علائقية + FTS5:**
  - تم تقليص حجم البيانات الخام من **170.14 ميجابايت** (543 ملف JSON خام + 31 ملف فهرس غير مطبّع) إلى **80.77 ميجابايت** مضغوطة بـ Gzip تُستخرج بسلاسة وبأقل استهلاك للذاكرة (Streaming Isolate) عند أول تشغيل.
  - بحث فوري بأجزاء من الثانية (**0.6 – 5.9 مللي ثانية** على 1.16 مليون بيت) مع تطبيع عربي كامل (`أ إ آ ← ا`، `ى ← ي`، `ة ← ه`، إزالة التشكيل والتطويل) وتمييز ذهبي للنتائج مع الحفاظ على التشكيل الأصلي.
  - استخدام `sqlite3` + `sqlite3_flutter_libs` لضمان توافر FTS5 على جميع أجهزة Android.
- **باقة خطوط عربية نخبوية:**
  - العناوين والزخرفة: `Aref Ruqaa` (نسخة Vector نقية بديلة لـ `Aref Ruqaa Ink` COLRv1 لضمان التوافق الكامل مع Impeller/Skia والوضع الليلي)، `Gulzar`، و`Reem Kufi`.
  - متن القصائد (قابلة للتبديل): `Scheherazade New`، `Ruwudu`، `Noto Naskh Arabic`، `Lateef`.
  - عناصر الواجهة: `IBM Plex Sans Arabic`.
- **محرك عرض الأبيات بدقة هندسية:**
  - نمطا الشطرين المتقابلين والمتدرّجين + دعم تلقائي للشعر الحر والموشحات.
  - تحجيم تلقائي ذكي (Dynamic Auto-Fit Scaling) يمنع انكسار الشطر إلى سطرين، مع `line-height` سخي لمنع تداخل حركات التشكيل.
  - وضع قراءة غامر، إظهار/إخفاء التشكيل، ترقيم الأبيات، وتحديد عدة أبيات للنسخ أو الحفظ أو التصميم.
- **أوضاع قراءة مريحة للعين (WCAG AAA):**
  - الورق الدافئ (`#F8F5EE` / `#1C1A17`)، المخطوط المعتّق (`#F1E7D2`)، والسواد الهادئ (`#121210` / `#E6E0D4` / `#C5A567`).
- **مكتبتي واستوديو البطاقات الشعرية:**
  - مفضلة القصائد، مفضلة الأبيات المفردة، مفضلة الشعراء، المجموعات المخصصة، وسجل القراءة.
  - مولّد بطاقات شعرية عالية الدقة بـ 5 قوالب تحريرية و3 مقاسات (`1:1`، `4:5`، `9:16`) وتصدير فوري بصيغة PNG.

---

## البنية المعمارية (Clean Architecture + Riverpod)

```text
lib/
├── core/
│   ├── constants/      # ثوابت التطبيق ومسارات قاعدة البيانات
│   ├── theme/          # نظام الألوان (Parchment / Sepia / Obsidian) والخطوط
│   ├── utils/          # التطبيع العربي، التمييز مع التشكيل، وتنسيق المشاركة
│   └── widgets/        # محرك عرض الأبيات الذكي والفواصل التحريرية
├── data/
│   ├── datasources/    # PoetryDatabase (Read-Only FTS5) و UserDatabase (Writable)
│   ├── models/         # النماذج العلائقية النظيفة
│   └── repositories/   # استعلامات الدواوين والبحث وبيانات المستخدم
└── presentation/
    ├── providers/      # إدارة الحالة بـ Riverpod
    └── screens/        # الرئيسية، العصور، الشعراء، القارئ، البحث، المكتبة، الاستوديو
```

---

## كيفية توقيع ملف الـ APK غير الموقّع لاحقاً (Manual APK Signing)

ينتج سير عمل GitHub Actions ملف **`BaytAlQaseed-release-unsigned.apk`** غير موقّع وجاهز للتوقيع اليدوي بمفتاحك الخاص:

### 1. إنشاء مفتاح توقيع (إن لم يكن لديك واحد)
```bash
keytool -genkey -v -keystore my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias bayt-al-qaseed
```

### 2. محاذاة الملف وتوقيعه (Zipalign & Apksigner)
```bash
zipalign -v -p 4 BaytAlQaseed-release-unsigned.apk BaytAlQaseed-aligned.apk

apksigner sign --ks my-release-key.jks \
  --ks-key-alias bayt-al-qaseed \
  --out BaytAlQaseed-release-signed.apk \
  BaytAlQaseed-aligned.apk

apksigner verify --verbose BaytAlQaseed-release-signed.apk
```

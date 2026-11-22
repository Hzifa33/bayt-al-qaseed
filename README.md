# بيت القصيد — ديوان الشعر العربي (v1.1.0)

موسوعةٌ شعريةٌ عربيةٌ فاخرة بلغة **Flutter / Dart**، مصمَّمة بهوية تحريرية دافئة تجمع بين الهدوء البصري والروح العربية الراقية، وتعمل بالكامل دون اتصال بالإنترنت وبلا إعلانات.

---

## أبرز المزايا

- **خزانة شعرية شاملة:** **542 شاعراً** عبر **11 عصراً أدبياً**، **90,238 قصيدة**، و**1,162,119 بيتاً شعرياً** (أكثر من 96% منها مضبوطة بالتشكيل).
- **أوضاع قراءة مريحة للعين:** الورق الدافئ، المخطوط المعتّق، السواد الهادئ، ووضع **ألوان النظام (Material You)** بأيقونة مخصصة.
- **باقة خطوط عربية نخبوية:** `Aref Ruqaa`، `Gulzar`، `Reem Kufi`، `Scheherazade New`، `Mirza`، `Ruwudu`، `Amiri Quran`، `Katibeh`، `Harmattan`، `Lateef`، و`IBM Plex Sans Arabic`.
- **محرك عرض أبيات متماثل الجانبين:** نمط متدرّج افتراضي ومتقابل اختياري مع موازنة هندسية ذكية بين الصدر والعجز، ودرج تخصيص حيّ غير حاجب للقصيدة.
- **تصفّح فائق السلاسة:** فهرسة مقسّمة بالقافية والبحر والحرف مع بكرة تنقل سريع جانبية، وصفحة مستقلة لسيرة الشاعر، وبحث دقيق على مستوى البيت الواحد مع خيارات العبارة المتتابعة ومطابقة أجزاء الكلمة.
- **ديوان البطاقات الشعرية:** مولّد بطاقات عالية الدقة من 4 تبويبات منظّمة (القالب، الخط، المقاس، العناصر).

---

## المطوّر

- **المطوّر:** [`hzifa33`](https://hzifa33.com)
- **الموقع الشخصي:** [https://hzifa33.com](https://hzifa33.com)
- **المستودع:** [https://github.com/Hzifa33/bayt-al-qaseed](https://github.com/Hzifa33/bayt-al-qaseed)

---

## توقيع ملف الـ APK غير الموقّع يدوياً

```bash
zipalign -v -p 4 BaytAlQaseed-release-unsigned.apk BaytAlQaseed-aligned.apk

apksigner sign --ks my-release-key.jks \
  --ks-key-alias bayt-al-qaseed \
  --out BaytAlQaseed-release-signed.apk \
  BaytAlQaseed-aligned.apk

apksigner verify --verbose BaytAlQaseed-release-signed.apk
```

import 'arabic_normalizer.dart';

/// Complete curated Arabic poetic lexicon & thematic mapping for all 127 feelings
/// in the Feelings Wheel (عجلة المشاعر), ensuring every root, branch, and sub-feeling
/// surfaces genuinely distinct and thematically relevant poems.
class FeelingLexicon {
  FeelingLexicon._();

  static const Map<String, List<String>> _keywordsBySlug = {
    // ── 1. السرور (Happy) ──
    'alsurur': ['سرور', 'فرح', 'سعد', 'هناء', 'بشر', 'ابتهاج'],
    'almarah': ['مرح', 'طرب', 'ضحك', 'لهو', 'انشراح', 'نشو'],
    'alsabwa': ['صبو', 'شوق', 'غرام', 'عشق', 'هوي', 'وجد'],
    'alabath': ['عبث', 'لعب', 'مزاح', 'دعاب', 'هزل', 'مجن'],
    'alrida': ['رضا', 'قناع', 'رضي', 'ارتياح', 'اطمئن'],
    'alhurriya': ['حري', 'احرار', 'طليق', 'انطلاق', 'قيد', 'تحرر'],
    'albahja': ['بهج', 'زهر', 'ربيع', 'اشراق', 'بشاش', 'نضير'],
    'alihtimam': ['اهتمام', 'عناي', 'التفات', 'شغف', 'حرص'],
    'alfudul': ['فضول', 'استطلاع', 'تطلع', 'سؤال', 'بحث'],
    'altasaul': ['تساءل', 'سؤال', 'كيف', 'هل', 'عجب', 'لماذا'],
    'alfakhr': ['فخر', 'مجد', 'شرف', 'علا', 'سؤدد', 'نسب'],
    'alzafar': ['ظفر', 'نصر', 'فتح', 'غلب', 'فوز', 'انتصار'],
    'alitidad': ['اعتداد', 'شموخ', 'انف', 'همة', 'كبر', 'اباء'],
    'alqabul': ['قبول', 'ترحيب', 'اقبال', 'وصال', 'تلق'],
    'alijlal': ['اجلال', 'توقير', 'تعظيم', 'هيبة', 'اكبار'],
    'altaqdir': ['تقدير', 'فضل', 'ثناء', 'مقام', 'قدر', 'اكرام'],
    'alizza': ['عز', 'عزة', 'منعة', 'سياد', 'ملك', 'سلطان'],
    'aliqdam': ['اقدام', 'شجاع', 'بسل', 'سيف', 'بطل', 'حرب'],
    'alibda': ['ابداع', 'فن', 'قريض', 'شعر', 'بيان', 'بلاغ'],
    'alsakina': ['سكين', 'هدوء', 'سلام', 'طمأنين', 'امان', 'صفاء'],
    'alhubb': ['حب', 'محب', 'حبيب', 'عشق', 'وداد', 'هوى'],
    'alshukr': ['شكر', 'حمد', 'ثناء', 'نعمة', 'امتنان', 'منة'],
    'althiqa': ['ثق', 'يقين', 'عهد', 'وفاء', 'امان', 'صدق'],
    'alriqqa': ['رق', 'رقيق', 'لطاف', 'نسيم', 'عذب', 'حنان'],
    'almawadda': ['مود', 'ود', 'الف', 'اخاء', 'صحب', 'خليل'],
    'altafaul': ['تفاؤل', 'بشرى', 'فجر', 'صبح', 'غد', 'اشراق'],
    'alamal': ['امل', 'رجاء', 'منى', 'امني', 'تمن', 'طمع'],
    'alilham': ['الهام', 'وحي', 'خيال', 'رؤيا', 'الهام', 'افق'],

    // ── 2. التعجب (Surprised) ──
    'altaajjub': ['عجب', 'عجيب', 'اعجب', 'غريب', 'سبحان'],
    'alirtiya': ['ارتاع', 'روع', 'فزع', 'بغت', 'مفاج'],
    'alsadma': ['صدم', 'خطب', 'فاجع', 'نازل', 'داهي'],
    'aljaza': ['جزع', 'هلع', 'فزع', 'مصاب', 'بلوى'],
    'alhayra': ['حير', 'حيران', 'تيه', 'ضلال', 'تردد'],
    'khaybat-alzann': ['خيب', 'ظن', 'سراب', 'خداع', 'وهم'],
    'aliltibas': ['التباس', 'غامض', 'شبه', 'لغز', 'مبهم'],
    'alinbihar': ['انبهار', 'بهر', 'باهر', 'جمال', 'روعة', 'بديع'],
    'aldhuhul': ['ذهول', 'ذاهل', 'دهش', 'مدهش', 'حائر'],
    'alhayba': ['هيب', 'جلال', 'وقار', 'مهاب', 'عظم'],
    'alhamasa': ['حماس', 'نخو', 'همة', 'ثور', 'نهض', 'عزم'],
    'altalahhuf': ['لهف', 'تلهف', 'شوق', 'انتظار', 'توق'],
    'alnashat': ['نشاط', 'حيو', 'وثب', 'نهوض', 'بكر', 'سعي'],

    // ── 3. الضيق (Bad) ──
    'aldiq': ['ضيق', 'كرب', 'عسر', 'شدة', 'ضنك'],
    'alsaam': ['سأم', 'ملل', 'سئمت', 'ضجر', 'مللت'],
    'alfutur': ['فتور', 'فتر', 'خمود', 'تراخ', 'برود'],
    'alkhumul': ['خمول', 'خامل', 'كسل', 'قعود', 'سبات'],
    'alinshighal': ['شغل', 'مشغول', 'شواغل', 'كدح', 'عناء'],
    'aldaght': ['ضغط', 'ثقل', 'عبء', 'حمل', 'ارهاق'],
    'alistijal': ['عجل', 'استعجال', 'سرع', 'بادِر', 'فوت'],
    'alkarb': ['كرب', 'بلاء', 'محن', 'شدائد', 'غمة'],
    'alinhak': ['انهاك', 'اعياء', 'نصب', 'كلال', 'لغوب'],
    'altaab': ['تعب', 'نصب', 'عناء', 'سهر', 'مشق'],
    'alwasan': ['وسن', 'نعاس', 'نوم', 'كرى', 'غفو', 'جفن'],
    'alshurud': ['شرود', 'شارد', 'ساه', 'سهو', 'تشتت'],

    // ── 4. الخوف (Fearful) ──
    'alkhawf': ['خوف', 'خائف', 'رهب', 'خشية', 'حذر'],
    'aldhur': ['ذعر', 'فزع', 'رعب', 'هول', 'فزع'],
    'qillat-alhila': ['حيل', 'عاجز', 'مغلوب', 'لا حيلة', 'اضطرار'],
    'alraw': ['روع', 'مروع', 'مخيف', 'فزع', 'وجف'],
    'alqalaq': ['قلق', 'ارق', 'سهاد', 'اضطراب', 'سهر'],
    'alghamm': ['غم', 'غمة', 'كدر', 'انقباض', 'هموم'],
    'alhamm': ['هم', 'هموم', 'شجون', 'كبد', 'مهموم'],
    'alwajal': ['وجل', 'خشي', 'توجس', 'ارتجاف', 'ريبة'],
    'alnaqs': ['نقص', 'تقصير', 'عيب', 'خلل', 'قاصر'],
    'alsaghar': ['صغار', 'هوان', 'مذل', 'ذليل', 'خنوع'],
    'aldaf': ['ضعف', 'ضعيف', 'وهن', 'عجز', 'خور'],
    'alhawan': ['هوان', 'مهان', 'ذل', 'استكان', 'خضوع'],
    'aldaala': ['ضآل', 'ضئيل', 'حقير', 'قليل', 'يسير'],
    'alsadd': ['صد', 'صدود', 'اعراض', 'جفو', 'منع'],
    'aliqsa': ['اقصاء', 'ابعاد', 'طرد', 'نفي', 'غربة'],
    'alkhashya': ['خشي', 'تقوى', 'ورع', 'رهب', 'خاشع'],
    'alidtirab': ['اضطراب', 'مضطرب', 'رجف', 'زلزال', 'موج'],
    'alinkishaf': ['انكشاف', 'فضيح', 'سر', 'كشف', 'علن'],

    // ── 5. الغضب (Angry) ──
    'alghadab': ['غضب', 'غاضب', 'سخط', 'ثأر', 'انتقام'],
    'alkhidhlan': ['خذلان', 'خذل', 'مخذول', 'تخلي', 'خيب'],
    'alghadr': ['غدر', 'غادر', 'خيان', 'خائن', 'نكث'],
    'alimtiad': ['امتعاض', 'تذمر', 'ضجر', 'انكار', 'استياء'],
    'aldhull': ['ذل', 'مذل', 'ذليل', 'عار', 'خزي'],
    'alizdira': ['ازدراء', 'احتقار', 'استخفاف', 'استصغار'],
    'alsukhriya': ['سخري', 'هزء', 'استهزاء', 'تهكم', 'هجاء'],
    'alhiqd': ['حقد', 'ضغين', 'غل', 'حسد', 'بغضاء'],
    'alniqma': ['نقم', 'انتقام', 'ثأر', 'عقاب', 'بطش'],
    'alintihak': ['انتهاك', 'ظلم', 'جور', 'عدوان', 'بغي'],
    'alsukht': ['سخط', 'ساخط', 'غضب', 'نقمة', 'تبرم'],
    'alghayz': ['غيظ', 'مغتاظ', 'كمد', 'حرد', 'حنق'],
    'alghayra': ['غير', 'غيار', 'حسد', 'عذول', 'واش'],
    'albatsh': ['بطش', 'سيف', 'رمح', 'قتال', 'سطو'],
    'alistifzaz': ['استفزاز', 'تحد', 'مبارز', 'وعيد', 'تهديد'],
    'aladawa': ['عداو', 'عدو', 'خصم', 'خصام', 'عداء'],
    'alihbat': ['احباط', 'خيبة', 'قنوط', 'فشل', 'عثر'],
    'alhanaq': ['حنق', 'غضب', 'غيظ', 'ثائر', 'هائج'],
    'altabarrum': ['تبرم', 'ضجر', 'شكوى', 'تأفف', 'عتب'],
    'aljafa': ['جفاء', 'جفو', 'قطيع', 'بعاد', 'صدود'],
    'alintiwa': ['انطواء', 'عزل', 'وحدة', 'انفراد', 'صمت'],
    'altabalud': ['تبلد', 'جمود', 'قسوة', 'صخر', 'بلاد'],
    'alintiqad': ['نقد', 'عتاب', 'لوم', 'تأنيب', 'هجاء'],
    'alshakk': ['شك', 'ريب', 'ارتياب', 'ظن', 'تشكيك'],
    'alistihana': ['استهان', 'تهاون', 'استخفاف', 'لامبال'],

    // ── 6. الاشمئزاز (Disgusted) ──
    'alishmizaz': ['ذم', 'قبح', 'بخل', 'لؤم', 'دني'],
    'alistinkar': ['انكار', 'استنكار', 'رفض', 'منكر', 'عجب'],
    'allawm': ['لوم', 'لائم', 'عذل', 'عذول', 'ملام', 'عتب'],
    'alkhajal': ['خجل', 'حياء', 'استحياء', 'حشمة', 'خفر'],
    'alkhayba': ['خيب', 'خائب', 'حسرة', 'خسران', 'ضياع'],
    'alistifza': ['فظيع', 'شنع', 'مروع', 'منكر', 'فاجع'],
    'altaqazzuz': ['قبح', 'قبيح', 'دناء', 'خسة', 'نذال'],
    'alistiqbah': ['استقباح', 'قبيح', 'شنيع', 'ذميم', 'سوء'],
    'alghathayan': ['مرض', 'سقم', 'داء', 'علل', 'توجع'],
    'albughd': ['بغض', 'كره', 'مقت', 'شنآن', 'عداء'],
    'alnufur': ['نفور', 'نافر', 'نأى', 'فرار', 'اجتناب'],
    'alhawl': ['هول', 'اهوال', 'رهيب', 'مفزع', 'خطب'],
    'altaraddud': ['تردد', 'حيرة', 'احجام', 'توقف', 'ارتياب'],

    // ── 7. الحزن (Sad) ──
    'alhuzn': ['حزن', 'حزين', 'دمع', 'بكاء', 'شجن'],
    'alalam': ['الم', 'وجع', 'جرح', 'جراح', 'أنين', 'توجع'],
    'alharaj': ['حرج', 'ضيق', 'خجل', 'كلف', 'عنت'],
    'alkaaba': ['كآب', 'كئيب', 'اكتئاب', 'انقباض', 'شحوب'],
    'alinkisar': ['انكسار', 'مكسور', 'كسر', 'انهزام', 'ذبول'],
    'alfaragh': ['فراغ', 'خلاء', 'قفر', 'وحش', 'سكون'],
    'aldhanb': ['ذنب', 'ذنوب', 'خطيئ', 'اثم', 'توبة', 'استغفار'],
    'alkhizy': ['خزي', 'عار', 'شنار', 'فضيح', 'ندامة'],
    'alnadam': ['ندم', 'ندام', 'توبة', 'اسف', 'حسرة', 'ليت'],
    'alyas': ['يأس', 'قنوط', 'يائس', 'انقطاع', 'ضياع'],
    'alasa': ['اسى', 'رثاء', 'نعي', 'موت', 'قبر', 'فقد'],
    'alajz': ['عجز', 'عاجز', 'شيب', 'كبر', 'ضعف'],
    'alwahn': ['وهن', 'ضعف', 'نحول', 'سقم', 'ضنى'],
    'aldaym': ['ضيم', 'ظلم', 'مظلوم', 'قهر', 'جور'],
    'alhashasha': ['هش', 'رقيق', 'ذابل', 'نحيل', 'ضعيف'],
    'alwahsha': ['وحش', 'غرب', 'غريب', 'وحدة', 'اطلال'],
    'aluzla': ['عزل', 'انزواء', 'وحدة', 'خلوة', 'صمت'],
    'alhajr': ['هجر', 'فراق', 'بين', 'وداع', 'بعاد', 'نوى'],
  };

  /// Returns targeted Arabic keywords for a specific feeling slug.
  /// Never dilutes a leaf feeling with broad root words so each chip produces
  /// its own distinct poem selection.
  static List<String> keywordsFor(String slug, String arabicName) {
    final mapped = _keywordsBySlug[slug];
    if (mapped != null && mapped.isNotEmpty) return mapped;

    final norm = ArabicNormalizer.normalize(arabicName);
    final tokens = ArabicNormalizer.tokenize(norm)
        .map((t) => t.startsWith('ال') && t.length > 4 ? t.substring(2) : t)
        .where((t) => t.length >= 3)
        .toList();
    return tokens;
  }

  /// Returns the best matching theme slug(s) for fallback/supplementation.
  static List<String> themeSlugsFor(String slug, String rootSlug) {
    switch (slug) {
      case 'alfakhr':
      case 'alzafar':
      case 'alitidad':
      case 'alizza':
      case 'aliqdam':
      case 'alhamasa':
        return const ['alhamasa', 'almadih'];
      case 'alsabwa':
      case 'alhubb':
      case 'almawadda':
      case 'alriqqa':
      case 'alhajr':
      case 'alsadd':
      case 'alghayra':
        return const ['alnasib', 'alwasf'];
      case 'alijlal':
      case 'altaqdir':
      case 'alshukr':
      case 'alqabul':
        return const ['almadih', 'alhikma'];
      case 'almarah':
      case 'albahja':
      case 'alinbihar':
      case 'alibda':
        return const ['alwasf', 'alnasib'];
      case 'aldhanb':
      case 'alnadam':
      case 'alkhashya':
      case 'alsakina':
      case 'alrida':
        return const ['alzuhd', 'alhikma'];
      case 'alasa':
      case 'alwahsha':
      case 'alalam':
      case 'alkaaba':
        return const ['alritha', 'alitab'];
      case 'alsukhriya':
      case 'alizdira':
      case 'alghadr':
      case 'alhiqd':
      case 'albughd':
      case 'alistiqbah':
        return const ['alhija', 'alitab'];
      case 'allawm':
      case 'alintiqad':
      case 'aljafa':
      case 'altabarrum':
        return const ['alitab', 'alhija'];
      default:
        return switch (rootSlug) {
          'alsurur' => const ['alnasib', 'almadih', 'alwasf'],
          'alhuzn' => const ['alritha', 'alitab', 'alzuhd'],
          'alghadab' => const ['alhija', 'alhamasa', 'alitab'],
          'alkhawf' => const ['alzuhd', 'alhikma'],
          'alishmizaz' => const ['alhija', 'alitab'],
          'altaajjub' => const ['alhikma', 'alwasf'],
          'aldiq' => const ['alitab', 'alzuhd', 'alritha'],
          _ => const ['alhikma', 'alnasib'],
        };
    }
  }
}

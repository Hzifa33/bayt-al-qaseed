class Era {
  const Era({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.poetCount,
    required this.poemCount,
  });

  final int id;
  final String name;
  final int displayOrder;
  final int poetCount;
  final int poemCount;

  /// Refined poetic subtitle for each historical era.
  String get subtitle => switch (id) {
    1 => 'المعلّقات وفحول البادية',
    2 => 'بين الجاهلية وصدر الإسلام',
    3 => 'شعر الفتوح والدعوة',
    4 => 'النقائض والغزل العذري',
    5 => 'ذروة البديع والحكمة',
    6 => 'الموشحات ورياض قرطبة',
    7 => 'ديوان القاهرة والمغرب',
    8 => 'شعر الجهاد والنهضة',
    9 => 'البديعيات والمدائح النبوية',
    10 => 'بواكير الإحياء الأدبي',
    11 => 'النهضة والرومانسية والتجديد',
    12 => 'أصوات الشعر العربي المعاصر',
    13 => 'شعراء لم يُؤرَّخ عصرهم بعد',
    _ => 'ديوان الشعر العربي',
  };

  /// Subtle era period hint.
  String get periodHint => switch (id) {
    1 => 'قبل الهجرة',
    2 => 'القرن ١ هـ',
    3 => '١ – ٤٠ هـ',
    4 => '٤١ – ١٣٢ هـ',
    5 => '١٣٢ – ٦٥٦ هـ',
    6 => '٩٢ – ٨٩٧ هـ',
    7 => '٢٩٧ – ٥٦٧ هـ',
    8 => '٥٦٩ – ٦٤٨ هـ',
    9 => '٦٤٨ – ٩٢٣ هـ',
    10 => '٩٢٣ – ١٢٢٠ هـ',
    11 => '١٨٠٠ – ١٩٧٠ م',
    12 => '١٩٧٠ م – اليوم',
    13 => 'عام',
    _ => '',
  };
}

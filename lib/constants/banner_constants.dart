/// قائمة صور البانر للشاشة الرئيسية.
///
/// كل الصور 1280×720 (16:9 landscape) — تتلاءم مع `BoxFit.cover`
/// بدون قصّ مرئي. لتغيير الصور أو إضافة جديدة:
/// 1. ضع الصورة الجديدة في `assets/banners/banner_N.jpg`
/// 2. أضف مدخل جديد لهذه القائمة
/// 3. لو احتجت قصّ تلقائي لـ landscape، شغّل:
///    `python scripts/banner_to_landscape.py`
const List<String> kBannerImages = [
  'assets/banners/banner_1.jpg',  // رجالي راقي
  'assets/banners/banner_2.jpg',  // نسائي elegant
  'assets/banners/banner_3.jpg',  // أطفال
  'assets/banners/banner_4.jpg',  // أحذية
  'assets/banners/banner_5.jpg',  // مجوهرات
  'assets/banners/banner_6.jpg',  // تجميل
  'assets/banners/banner_7.jpg',  // إلكترونيات
  'assets/banners/banner_8.jpg',  // ساعات
  'assets/banners/banner_9.jpg',  // ثياب نسائي
  'assets/banners/banner_10.jpg', // جلابيات رجالي
];

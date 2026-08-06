/// الأقسام التي تستوجب اختيار مقاس ولون (ملابس + أحذية + ثياب)
/// استخدام Set لأداء O(1) في عملية contains
const Set<String> kCategoriesWithVariants = {
  'ملابس نسائي',
  'ملابس رجالي',
  'ملابس أطفال',
  'جلابية',
  'أحذية',
  'ثياب',
};

/// اسم قسم ملابس الأطفال — مرجع موحَّد لتجنّب الـ typos.
const String kKidsClothingCategory = 'ملابس أطفال';

/// اسم قسم الإكسسوارات — مرجع موحَّد لتجنّب الـ typos.
/// هذا القسم لا يستوجب مقاسات، لكنه يسمح باختيار لون (اختياري وليس إجبارياً)
/// خلافاً لأقسام [kCategoriesWithVariants] التي يُجبَر فيها اختيار لون واحد.
const String kAccessoriesCategory = 'إكسسوارات';

/// هل القسم يستخدم مقاسات حسب العمر (السن) بدلاً من S/M/L؟
bool isKidsCategory(String? category) => category == kKidsClothingCategory;

/// مقاسات ملابس البالغين (رجالي/نسائي/جلابية/ثياب).
const List<String> kAdultClothingSizes = [
  'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', '4XL', '5XL', '6XL',
  'Free Size',
];

/// مقاسات الأحذية.
const List<String> kShoeSizes = [
  '34', '35', '36', '37', '38', '39', '40', '41', '42',
  '43', '44', '45', '46', '47', '48',
];

/// مقاسات ملابس الأطفال — حسب الفئة العمرية.
/// تغطّي من الرضيع (0 شهر) حتى سن المراهقة (16 سنة).
const List<String> kKidsAgeSizes = [
  '0-3 شهور',
  '3-6 شهور',
  '6-9 شهور',
  '9-12 شهر',
  '1-2 سنة',
  '2-3 سنوات',
  '3-4 سنوات',
  '4-5 سنوات',
  '5-6 سنوات',
  '6-7 سنوات',
  '7-8 سنوات',
  '8-10 سنوات',
  '10-12 سنة',
  '12-14 سنة',
  '15 سنة',
  '16 سنة',
];

/// يرجع لائحة المقاسات المتاحة بناءً على القسم.
List<String> availableSizesForCategory(String? category) {
  if (category == null) return kAdultClothingSizes;
  if (isKidsCategory(category)) return kKidsAgeSizes;
  if (category == 'أحذية') return kShoeSizes;
  return kAdultClothingSizes;
}

/// تسمية حقل المقاس حسب القسم (للعرض في UI).
/// "السن" للأطفال، "المقاس" لباقي الأقسام.
String sizeLabelForCategory(String? category) =>
    isKidsCategory(category) ? 'السن' : 'المقاس';

const List<String> kProductCategories = [
  'ملابس نسائي',
  'ملابس رجالي',
  'ملابس أطفال',
  'جلابية',
  'إكسسوارات',
  'أحذية',
  'العطور',
  'ثياب',
  'ساعات',
  'مستحضرات العناية والجمال',
  'إلكترونيات والهواتف',
];

const List<Map<String, dynamic>> kCategoryData = [
  {
    'name': 'ملابس نسائي',
    'height': 240.0,
    'image': 'assets/categories/cat_women.jpg',
  },
  {
    'name': 'ملابس رجالي',
    'height': 180.0,
    'image': 'assets/categories/cat_men.jpg',
  },
  {
    'name': 'ملابس أطفال',
    'height': 220.0,
    'image': 'assets/categories/cat_kids.jpg',
  },
  {
    'name': 'جلابية',
    'height': 210.0,
    'image': 'assets/categories/cat_jalabiya.jpg',
  },
  {
    'name': 'إكسسوارات',
    'height': 200.0,
    'image': 'assets/categories/cat_accessories.jpg',
  },
  {
    'name': 'أحذية',
    'height': 180.0,
    'image': 'assets/categories/cat_shoes.jpg',
  },
  {
    'name': 'العطور',
    'height': 200.0,
    'image': 'assets/categories/cat_perfumes.jpg',
  },
  {
    'name': 'ثياب',
    'height': 220.0,
    'image': 'assets/categories/cat_thiyab.jpg',
  },
  {
    'name': 'ساعات',
    'height': 180.0,
    'image': 'assets/categories/cat_watches.jpg',
  },
  {
    'name': 'مستحضرات العناية والجمال',
    'height': 210.0,
    'image': 'assets/categories/cat_beauty.jpg',
  },
  {
    'name': 'إلكترونيات والهواتف',
    'height': 190.0,
    'image': 'assets/categories/cat_elec_phones.jpg',
  },
];

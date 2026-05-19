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

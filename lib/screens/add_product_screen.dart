import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/core/utils/color_utils.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/features/products/domain/usecases/add_product.dart';
import 'package:my_fashion_app/features/products/domain/usecases/update_product.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? productId;

  const AddProductScreen({
    super.key,
    this.productData,
    this.productId,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF800000);
  static const Color _surface = Color(0xFF121212);
  static const Color _inputFill = Color(0xFF1B1B1B);
  static const Color _chipBase = Color(0xFF4A1F1F);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  /// صور محفوظة سابقاً (وضع التعديل) واحتُفظ بها — روابط Firebase Storage.
  List<String> _existingImageUrls = [];
  /// صور جُديدة اختارها المستخدم من المعرض ولم تُرفع بعد.
  List<XFile> _pickedImages = [];
  bool _isSaving = false;
  int _currentStep = 0;

  late List<String> _selectedSizes;
  late List<String> _selectedColors;
  late String _selectedGender;
  String? _selectedCategory;
  String? _selectedState; // Sudanese state where product is located

  // المقاسات الآن في lib/constants/category_constants.dart:
  // - kAdultClothingSizes (للبالغين)
  // - kKidsAgeSizes (للأطفال — حسب العمر)
  // - kShoeSizes (للأحذية)
  // نستخدم availableSizesForCategory(category) للاختيار التلقائي.
  // الألوان أصبحت hex codes (مثلاً '#FFC62828') عبر ColorPicker —
  // لا حاجة لقائمة ثابتة. حذفنا _availableColors و _colorPalette.
  final List<String> _sudanStates = [
    'الخرطوم', 'الجزيرة', 'النيل الأبيض', 'النيل الأزرق', 'نهر النيل',
    'البحر الأحمر', 'الشمالية', 'كسلا', 'القضارف', 'سنار',
    'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'وسط دارفور', 'شرق دارفور', 'غرب دارفور',
  ];
  final List<String> _genders = ['رجالي', 'نسائي', 'للجنسين'];
  // الألوان السريعة المقترَحة في الـ picker (للوصول السريع)
  static const List<Color> _quickColors = [
    Colors.black, Colors.white, Color(0xFFC62828), Color(0xFF0D47A1),
    Color(0xFF2E7D32), Color(0xFFF9A825), Color(0xFFE91E8C),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00897B),
    Color(0xFFD4AF37), Color(0xFF5D4037), Color(0xFF8E8E8E),
    Color(0xFFC0C0C0), Color(0xFF880E4F),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSizes = [];
    _selectedColors = [];
    _selectedGender = 'للجنسين';
    _loadProductData();
  }

  void _loadProductData() {
    if (widget.productData != null) {
      final data = widget.productData!;
      _titleController.text = data['title'] ?? '';
      _priceController.text = (data['price'] ?? '').toString();
      _descriptionController.text = data['description'] ?? '';
      _stockController.text = (data['stockQuantity'] ?? '').toString();
      _selectedSizes = List<String>.from(data['sizes'] ?? []);
      _selectedColors = List<String>.from(data['colors'] ?? []);
      _existingImageUrls = List<String>.from(data['imageUrls'] ?? []);
      _selectedGender = data['gender'] ?? 'للجنسين';
      final savedCategory = data['category']?.toString();
      _selectedCategory =
          kProductCategories.contains(savedCategory) ? savedCategory : null;
      final savedState = data['state']?.toString();
      _selectedState = _sudanStates.contains(savedState) ? savedState : null;
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await ImagePicker().pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked.isNotEmpty) {
        setState(() {
          _pickedImages = [..._pickedImages, ...picked];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل اختيار الصور: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removePickedImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  // ── معاينة أفقية لكل الصور (المحفوظة سابقاً + المُختارة حديثاً) ─────
  // مع زر حذف لكل صورة قبل الرفع.
  Widget _buildImagePreviewList() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _existingImageUrls.length; i++)
            _buildImageThumb(
              key: ValueKey('existing_$i${_existingImageUrls[i]}'),
              image: Image.network(
                _existingImageUrls[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
              onRemove: () => _removeExistingImage(i),
            ),
          for (var i = 0; i < _pickedImages.length; i++)
            _buildImageThumb(
              key: ValueKey('picked_${_pickedImages[i].path}'),
              image: Image.file(
                File(_pickedImages[i].path),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
              onRemove: () => _removePickedImage(i),
            ),
        ],
      ),
    );
  }

  Widget _buildImageThumb({
    required Key key,
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image,
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isShoeCategory => _selectedCategory == 'أحذية';
  bool get _isKidsCategory => isKidsCategory(_selectedCategory);

  /// هل القسم المختار يحتاج مقاسات وألوان (إجبارياً)؟
  bool get _needsVariants =>
      _selectedCategory != null &&
      kCategoriesWithVariants.contains(_selectedCategory);

  /// هل القسم المختار هو الإكسسوارات؟ — يُظهر منتقي الألوان لكن كخيار
  /// اختياري (لا يُجبَر اختيار لون قبل الحفظ)، وبدون مقاسات.
  bool get _isAccessoriesCategory =>
      _selectedCategory == kAccessoriesCategory;

  /// هل يظهر منتقي الألوان؟ — للأقسام التي تحتاج variants إجبارياً،
  /// أو الإكسسوارات (اختياري).
  bool get _showsColorPicker => _needsVariants || _isAccessoriesCategory;

  /// المقاسات المتاحة بناءً على القسم — أحذية / أطفال (سن) / ملابس عادية.
  List<String> get _availableSizes =>
      availableSizesForCategory(_selectedCategory);

  // استخدام hintText بدلاً من labelText لتجنب مشكلة قطع النص في Stepper
  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: _inputFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _gold, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  void _toggleSelection(List<String> values, String value) {
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else {
        values.add(value);
      }
    });
  }

  Widget _buildSelectionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: _chipBase,
      selectedColor: _gold,
      checkmarkColor: Colors.black,
      side: BorderSide(
        color: isSelected ? _gold : Colors.white24,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildSectionHeading(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _gold,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  // ── عرض لون مختار (swatch + زر حذف) ─────────────────────────────────
  Widget _buildColorChip(String colorCode) {
    final color = ColorUtils.parse(colorCode);
    final isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isLight ? Colors.white54 : Colors.white24,
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ColorUtils.displayLabel(colorCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () =>
                setState(() => _selectedColors.remove(colorCode)),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  // ── زر "+ إضافة لون" — يفتح الـ ColorPicker dialog ──────────────────
  Widget _buildAddColorButton() {
    return GestureDetector(
      onTap: _showColorPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: _gold, size: 18),
            SizedBox(width: 4),
            Text(
              'إضافة لون',
              style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showColorPicker() async {
    Color picked = _gold;
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'اختر لوناً',
          style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
            pickerAreaHeightPercent: 0.7,
            pickerAreaBorderRadius: BorderRadius.circular(12),
          ),
        ),
        actions: [
          // الألوان السريعة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickColors
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white24, width: 1),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('إضافة',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    final hex = ColorUtils.toHex(result);
    if (!_selectedColors.contains(hex)) {
      setState(() => _selectedColors.add(hex));
    }
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار صورة واحدة على الأقل للمنتج.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_needsVariants) {
      if (_selectedSizes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار مقاس واحد على الأقل.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_selectedColors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار لون واحد على الأقل.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String title = _titleController.text.trim();
      final String description = _descriptionController.text.trim();
      final double price = double.parse(_priceController.text.trim());
      final String category = _selectedCategory!;
      final int stock = int.parse(_stockController.text.trim());

      final input = ProductInput(
        title: title,
        price: price,
        description: description,
        category: category,
        stockQuantity: stock,
        sizes: _needsVariants ? _selectedSizes : const <String>[],
        colors: _showsColorPicker ? _selectedColors : const <String>[],
        gender: _selectedGender,
        state: _selectedState ?? '',
        existingImageUrls: _existingImageUrls,
        newImages: _pickedImages.map((x) => File(x.path)).toList(),
      );

      if (widget.productId != null) {
        final res = await sl<UpdateProduct>()(UpdateProductParams(
          docId: widget.productId!,
          input: input,
        ));
        if (!mounted) return;
        final ok = res.isRight();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'تم تحديث المنتج بنجاح!'
              : res.fold((f) => f.message, (_) => '')),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        if (ok && mounted) Navigator.of(context).pop();
      } else {
        final res = await sl<AddProduct>()(input);
        if (!mounted) return;
        final ok = res.isRight();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'تمت إضافة المنتج بنجاح!'
              : res.fold((f) => f.message, (_) => '')),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        if (ok && mounted) Navigator.of(context).pop();
      }
      return;
    } catch (e, stackTrace) {
      debugPrint('Error saving product: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ المنتج: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepperTheme = Theme.of(context).copyWith(
      canvasColor: Colors.black,
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _gold,
            onPrimary: Colors.black,
            onSurface: Colors.white,
            surface: _surface,
          ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
    );

    return Theme(
      data: stepperTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.productId != null ? 'تعديل المنتج' : 'إضافة منتج'),
          iconTheme: const IconThemeData(color: _gold),
          titleTextStyle: const TextStyle(
            color: _gold,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.black,
        body: Form(
          key: _formKey,
          child: Stepper(
          currentStep: _currentStep,
          // الضغط على الأرقام (1-4) ينتقل مباشرة للخطوة
          onStepTapped: (step) {
            if (!_isSaving) setState(() => _currentStep = step);
          },
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() {
                _currentStep += 1;
              });
            } else {
              _saveProduct();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep -= 1;
              });
            }
          },
          steps: [
            // Step 1: Basic Information
            Step(
              title: const Text(
                'البيانات الأساسية',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('اسم المنتج'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'اسم المنتج مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('السعر'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'السعر مطلوب';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل سعرًا صحيحًا';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('الوصف'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الوصف مطلوب';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            // Step 2: Media
            Step(
              title: const Text(
                'الوسائط',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: _currentStep >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('اختر صور المنتج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _pickImages,
                  ),
                  const SizedBox(height: 16),
                  if (_existingImageUrls.isEmpty && _pickedImages.isEmpty)
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(
                        child: Text(
                          'لم يتم اختيار أي صور',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    _buildImagePreviewList(),
                ],
              ),
            ),
            // Step 3: Inventory & Category
            Step(
              title: const Text(
                'المخزون',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: _surface,
                    iconEnabledColor: _gold,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('الفئة'),
                    items: kProductCategories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        if (!kCategoriesWithVariants.contains(value)) {
                          // قسم لا يحتاج مقاسات إجبارية — امسح المقاسات السابقة
                          _selectedSizes.clear();
                        } else {
                          // قسم يحتاج مقاسات — احتفظ فقط بالمقاسات المتوافقة مع القسم الجديد
                          _selectedSizes = _selectedSizes
                              .where(_availableSizes.contains)
                              .toList();
                        }
                        // امسح الألوان فقط إن كان القسم الجديد لا يُظهر منتقي
                        // الألوان أصلاً (لا variants إجبارية ولا إكسسوارات).
                        if (!_showsColorPicker) {
                          _selectedColors.clear();
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الفئة مطلوبة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('كمية المخزون'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'كمية المخزون مطلوبة';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return 'أدخل كمية مخزون صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    dropdownColor: _surface,
                    iconEnabledColor: _gold,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('ولاية المنتج (السودان)'),
                    isExpanded: true,
                    items: _sudanStates
                        .map((state) => DropdownMenuItem<String>(
                              value: state,
                              child: Text(
                                state,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedState = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى تحديد ولاية المنتج';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            // Step 4: Attributes (Sizes, Colors, Gender)
            Step(
              title: const Text(
                'الخصائص',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              isActive: _currentStep >= 3,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── مقاسات — تظهر فقط للملابس والأحذية ──────────────
                  // ملابس الأطفال تستخدم فئات عمرية (السن) بدلاً من S/M/L.
                  if (_needsVariants) ...[
                    _buildSectionHeading(
                      _isKidsCategory ? 'اختر الفئة العمرية' : 'اختر المقاسات',
                      subtitle: _isKidsCategory
                          ? 'اختر فئة عمرية واحدة أو أكثر تناسب الطفل.'
                          : _isShoeCategory
                              ? 'اختر مقاسًا واحدًا أو أكثر للأحذية.'
                              : 'اختر مقاسًا واحدًا أو أكثر للملابس.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableSizes.map((size) {
                        final isSelected = _selectedSizes.contains(size);
                        return _buildSelectionChip(
                          label: size,
                          isSelected: isSelected,
                          onTap: () => _toggleSelection(_selectedSizes, size),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // ── ألوان — تظهر للملابس/الأحذية (إجباري) وللإكسسوارات
                  // (اختياري — يمكن الحفظ بدون اختيار أي لون).
                  if (_showsColorPicker) ...[
                    _buildSectionHeading(
                      'ألوان المنتج',
                      subtitle: _isAccessoriesCategory
                          ? 'اختياري — أضف لوناً أو أكثر إن أردت، أو تخطَّ هذه الخطوة.'
                          : 'اضغط "إضافة لون" لاختيار أي درجة لون من palette الكامل أو من الـ Quick Colors.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._selectedColors.map(_buildColorChip),
                        _buildAddColorButton(),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  // ── الفئة المستهدفة — تظهر دائماً ───────────────────
                  _buildSectionHeading('الفئة المستهدفة'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genders.map((gender) {
                      final isSelected = _selectedGender == gender;
                      return ChoiceChip(
                        label: Text(gender),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGender = gender;
                          });
                        },
                        backgroundColor: _chipBase,
                        selectedColor: _gold,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: isSelected ? _gold : Colors.white24,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _currentStep == 3
                          ? (_isSaving ? 'جارٍ الحفظ...' : 'حفظ المنتج')
                          : 'التالي',
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _isSaving ? null : details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: _gold),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('رجوع'),
                    ),
                ],
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}

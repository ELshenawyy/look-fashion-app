import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_fashion_app/constants/category_constants.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? productId;

  const AddProductScreen({
    Key? key,
    this.productData,
    this.productId,
  }) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF800000);
  static const Color _surface = Color(0xFF121212);
  static const Color _inputFill = Color(0xFF1B1B1B);
  static const Color _chipBase = Color(0xFF4A1F1F);
  static const Color _grey = Color(0xFF8E8E8E);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  XFile? _pickedImage;
  bool _isSaving = false;
  int _currentStep = 0;

  late List<String> _selectedSizes;
  late List<String> _selectedColors;
  late String _selectedGender;
  String? _selectedCategory;
  String? _selectedState; // Sudanese state where product is located

  final List<String> _clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  final List<String> _shoeSizes = ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];
  final List<String> _availableColors = [
    'Black', 'White', 'Red', 'Blue', 'Maroon', 'Gold', 'Grey',
    'Green', 'Navy', 'Brown', 'Orange', 'Yellow', 'Pink',
    'Purple', 'Beige', 'Turquoise', 'Burgundy', 'Cream', 'Khaki',
  ];
  final List<String> _sudanStates = [
    'الخرطوم', 'الجزيرة', 'النيل الأبيض', 'النيل الأزرق', 'نهر النيل',
    'البحر الأحمر', 'الشمالية', 'كسلا', 'القضارف', 'سنار',
    'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'وسط دارفور', 'شرق دارفور', 'غرب دارفور',
  ];
  final List<String> _genders = ['رجالي', 'نسائي', 'للجنسين'];
  late final Map<String, Color> _colorPalette = <String, Color>{
    'Black': Colors.black,
    'White': Colors.white,
    'Red': const Color(0xFFC62828),
    'Blue': const Color(0xFF0D47A1),
    'Maroon': _maroon,
    'Gold': _gold,
    'Grey': _grey,
    'Green': const Color(0xFF2E7D32),
    'Navy': const Color(0xFF1A237E),
    'Brown': const Color(0xFF5D4037),
    'Orange': const Color(0xFFE65100),
    'Yellow': const Color(0xFFF9A825),
    'Pink': const Color(0xFFE91E8C),
    'Purple': const Color(0xFF6A1B9A),
    'Beige': const Color(0xFFF5F0DC),
    'Turquoise': const Color(0xFF00897B),
    'Burgundy': const Color(0xFF880E4F),
    'Cream': const Color(0xFFFFFDD0),
    'Khaki': const Color(0xFFBDB76B),
  };

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
      _selectedGender = data['gender'] ?? 'للجنسين';
      final savedCategory = data['category']?.toString();
      _selectedCategory =
          kProductCategories.contains(savedCategory) ? savedCategory : null;
      final savedState = data['state']?.toString();
      _selectedState = _sudanStates.contains(savedState) ? savedState : null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = picked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل اختيار الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isShoeCategory => _selectedCategory == kProductCategories[3];

  List<String> get _availableSizes =>
      _isShoeCategory ? _shoeSizes : _clothingSizes;

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelStyle: const TextStyle(
        color: _gold,
        fontWeight: FontWeight.w700,
      ),
      labelStyle: const TextStyle(color: Colors.white70),
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

  Widget _buildColorOption(String colorName) {
    final colorValue = _colorPalette[colorName] ?? _grey;
    final isSelected = _selectedColors.contains(colorName);
    final isLightColor =
        ThemeData.estimateBrightnessForColor(colorValue) == Brightness.light;

    return GestureDetector(
      onTap: () => _toggleSelection(_selectedColors, colorName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSelected ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _gold : Colors.white10,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorValue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? _gold
                          : (colorName == 'White' ? Colors.white54 : Colors.white24),
                      width: isSelected ? 2.5 : 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: isLightColor ? Colors.black : Colors.white,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              colorName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null && widget.productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار صورة للمنتج.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مقاس واحد على الأقل.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار لون واحد على الأقل.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
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

      String imageUrl = '';

      // Upload new image if selected
      if (_pickedImage != null) {
        final File imageFile = File(_pickedImage!.path);
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String storagePath = 'products/prod_$timestamp.jpg';

        final Reference storageRef = FirebaseStorage.instance.ref(storagePath);
        final UploadTask uploadTask = storageRef.putFile(imageFile);

        await uploadTask.whenComplete(() {
          print('Upload task completed successfully');
        });

        imageUrl = await storageRef.getDownloadURL();
      } else if (widget.productData != null) {
        imageUrl = widget.productData!['imageUrl'] ?? '';
      }

      final productData = {
        'title': title,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        'category': category,
        'stockQuantity': stock,
        'sizes': _selectedSizes,
        'colors': _selectedColors,
        'gender': _selectedGender,
        'state': _selectedState ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.productId != null) {
        // Update existing product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .update(productData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المنتج بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new product
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة المنتج بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      print('Error saving product: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ المنتج: $e'),
          backgroundColor: Colors.red,
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
                    label: const Text('اختر صورة المنتج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(height: 16),
                  if (_pickedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_pickedImage!.path),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (widget.productData != null &&
                      widget.productData!['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.productData!['imageUrl'],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(
                        child: Text(
                          'لم يتم اختيار صورة',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
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
                        _selectedSizes = _selectedSizes
                            .where(_availableSizes.contains)
                            .toList();
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
                  _buildSectionHeading(
                    'اختر المقاسات',
                    subtitle: _isShoeCategory
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
                  _buildSectionHeading(
                    'اختر الألوان',
                    subtitle:
                        'استخدم دوائر الألوان بالأسفل لتحديد الخيارات المتاحة.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableColors.map(_buildColorOption).toList(),
                  ),
                  const SizedBox(height: 24),
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

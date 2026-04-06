import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? productData;
  final String? productId;

  const AddProductScreen({
    Key? key,
    this.productData,
    this.productId,
  }) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  XFile? _pickedImage;
  bool _isSaving = false;
  int _currentStep = 0;

  late List<String> _selectedSizes;
  late List<String> _selectedColors;
  late String _selectedGender;

  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _genders = ['Men', 'Women', 'Unisex'];

  @override
  void initState() {
    super.initState();
    _selectedSizes = [];
    _selectedColors = [];
    _selectedGender = 'Unisex';
    _loadProductData();
  }

  void _loadProductData() {
    if (widget.productData != null) {
      final data = widget.productData!;
      _titleController.text = data['title'] ?? '';
      _priceController.text = (data['price'] ?? '').toString();
      _descriptionController.text = data['description'] ?? '';
      _categoryController.text = data['category'] ?? '';
      _stockController.text = (data['stockQuantity'] ?? '').toString();
      _selectedSizes = List<String>.from(data['sizes'] ?? []);
      _selectedColors = List<String>.from(data['colors'] ?? []);
      _selectedGender = data['gender'] ?? 'Unisex';
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
          content: Text('Image selection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addColor() {
    final color = _colorController.text.trim();
    if (color.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a color (hex code or name)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      if (!_selectedColors.contains(color)) {
        _selectedColors.add(color);
        _colorController.clear();
      }
    });
  }

  void _removeColor(String color) {
    setState(() {
      _selectedColors.remove(color);
    });
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null && widget.productData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one size.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one color.'),
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
      final String category = _categoryController.text.trim();
      final int stock = int.parse(_stockController.text.trim());

      String imageUrl = '';

      // Upload new image if selected
      if (_pickedImage != null) {
        final File imageFile = File(_pickedImage!.path);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
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
            content: Text('Product updated successfully!'),
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
            content: Text('Product added successfully!'),
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
          content: Text('Failed to save product: $e'),
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
    _categoryController.dispose();
    _stockController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.productId != null ? 'Edit Product' : 'Add Product'),
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
              title: const Text('Basic Info'),
              isActive: _currentStep >= 0,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Price is required';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            // Step 2: Media
            Step(
              title: const Text('Media'),
              isActive: _currentStep >= 1,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select Product Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF800000),
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
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No image selected',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Step 3: Inventory & Category
            Step(
              title: const Text('Inventory'),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _categoryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Stock Quantity',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Stock quantity is required';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid stock quantity';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            // Step 4: Attributes (Sizes, Colors, Gender)
            Step(
              title: const Text('Attributes'),
              isActive: _currentStep >= 3,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Sizes:',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSizes.map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return FilterChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSizes.add(size);
                            } else {
                              _selectedSizes.remove(size);
                            }
                          });
                        },
                        backgroundColor: Colors.white12,
                        selectedColor: const Color(0xFF800000),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Colors:',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _colorController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'e.g., Red, #FF0000',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addColor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF800000),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedColors.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedColors.map((color) {
                        return FilterChip(
                          label: Text(color),
                          onSelected: (_) {},
                          onDeleted: () => _removeColor(color),
                          backgroundColor: Colors.white12,
                          labelStyle: const TextStyle(color: Colors.white70),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gender:',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
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
                        backgroundColor: Colors.white12,
                        selectedColor: const Color(0xFF800000),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
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
                      backgroundColor: const Color(0xFF800000),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(
                      _currentStep == 3
                          ? (_isSaving ? 'Saving...' : 'Save Product')
                          : 'Next',
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    ElevatedButton(
                      onPressed: _isSaving ? null : details.onStepCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

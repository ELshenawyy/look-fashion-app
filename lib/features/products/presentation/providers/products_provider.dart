import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/products/domain/usecases/fetch_products_page.dart';
import 'package:my_fashion_app/models/product.dart';

enum HomeSortMode { newArrivals, topSelling }

/// Provider يدير state للمنتجات في الشاشة الرئيسية مع pagination + search.
/// لا يستدعي Firebase مباشرة — يعتمد على use cases.
class ProductsProvider extends ChangeNotifier {
  final FetchProductsPage _fetchProductsPage;

  ProductsProvider({required FetchProductsPage fetchProductsPage})
      : _fetchProductsPage = fetchProductsPage;

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Failure? _failure;
  String? _selectedCategory;
  HomeSortMode _sortMode = HomeSortMode.newArrivals;
  DocumentSnapshot? _lastDoc;
  String _searchQuery = '';
  Timer? _searchDebounce;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Failure? get failure => _failure;
  String? get selectedCategory => _selectedCategory;
  HomeSortMode get sortMode => _sortMode;

  List<Product> get products {
    if (_searchQuery.isEmpty) return List.unmodifiable(_products);
    final q = _searchQuery.toLowerCase();
    return _products
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> init() => _loadInitial();
  Future<void> refresh() => _loadInitial();

  Future<void> _loadInitial() async {
    _isLoading = true;
    _failure = null;
    _products = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    final res = await _fetchProductsPage(FetchProductsPageParams(
      category: _selectedCategory,
      sortField: _sortField,
      descending: _sortDescending,
    ));

    res.fold((f) {
      _failure = f;
      _hasMore = false;
    }, (page) {
      _products = page.products;
      _lastDoc = page.lastDoc;
      _hasMore = _lastDoc != null && page.products.length == 10;
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    final res = await _fetchProductsPage(FetchProductsPageParams(
      category: _selectedCategory,
      sortField: _sortField,
      descending: _sortDescending,
      startAfter: _lastDoc,
    ));

    res.fold((f) {
      _hasMore = false;
    }, (page) {
      _products.addAll(page.products);
      _lastDoc = page.lastDoc;
      _hasMore = _lastDoc != null && page.products.length == 10;
    });

    _isLoadingMore = false;
    notifyListeners();
  }

  void setCategory(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _loadInitial();
  }

  void setSortMode(HomeSortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _loadInitial();
  }

  void setSearchQuery(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchQuery = q;
      notifyListeners();
    });
  }

  String get _sortField =>
      _sortMode == HomeSortMode.newArrivals ? 'createdAt' : 'stockQuantity';
  bool get _sortDescending => _sortMode == HomeSortMode.newArrivals;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/repositories/home_repository.dart';

enum HomeSortMode { newArrivals, topSelling }

class HomeProvider extends ChangeNotifier {
  final HomeRepository _repo = HomeRepository();

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _selectedCategory; // null = "الكل"
  HomeSortMode _sortMode = HomeSortMode.newArrivals;
  DocumentSnapshot? _lastDoc;
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── Getters ───────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
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

  // ── Init & Refresh ────────────────────────────────────────────────────
  Future<void> init() => _loadInitial();
  Future<void> refresh() => _loadInitial();

  Future<void> _loadInitial() async {
    _isLoading = true;
    _error = null;
    _products = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    try {
      final page = await _repo.fetchProducts(
        category: _selectedCategory,
        sortField: _sortField,
        descending: _sortDescending,
      );
      _products = page.products;
      _lastDoc = page.lastDoc;

      // عند التصفية بفئة يتم إرجاع كل نتائج الفئة دفعة واحدة (lastDoc=null)
      // لذا لا توجد صفحات إضافية.
      _hasMore = _lastDoc != null &&
          page.products.length == HomeRepository.pageSize;
    } catch (e) {
      _error = e.toString();
      _hasMore = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Load More (Pagination) — للكل فقط، غير مُفعَّل عند التصفية ────────
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repo.fetchProducts(
        category: _selectedCategory,
        sortField: _sortField,
        descending: _sortDescending,
        startAfter: _lastDoc,
      );
      _products.addAll(page.products);
      _lastDoc = page.lastDoc;
      _hasMore = _lastDoc != null &&
          page.products.length == HomeRepository.pageSize;
    } catch (e) {
      _hasMore = false;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Filters ───────────────────────────────────────────────────────────
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────
  String get _sortField =>
      _sortMode == HomeSortMode.newArrivals ? 'createdAt' : 'stockQuantity';

  // topSelling: ascending (أقل مخزون = أكثر مبيعاً)
  bool get _sortDescending => _sortMode == HomeSortMode.newArrivals;
}

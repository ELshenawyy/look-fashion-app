import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/products/domain/usecases/fetch_products_page.dart';
import 'package:my_fashion_app/features/products/domain/usecases/get_product_by_id.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_new_products.dart';
import 'package:my_fashion_app/models/product.dart';

enum HomeSortMode { newArrivals, topSelling }

/// Provider يدير state للمنتجات في الشاشة الرئيسية مع pagination + search.
/// لا يستدعي Firebase مباشرة — يعتمد على use cases.
class ProductsProvider extends ChangeNotifier {
  final FetchProductsPage _fetchProductsPage;
  final GetProductById _getProductById;
  final WatchNewProducts _watchNewProducts;

  // Stream subscription للمنتجات الجديدة (real-time)
  StreamSubscription<List<Product>>? _newProductsSub;
  DateTime? _subscribeSince;

  ProductsProvider({
    required FetchProductsPage fetchProductsPage,
    required GetProductById getProductById,
    required WatchNewProducts watchNewProducts,
  })  : _fetchProductsPage = fetchProductsPage,
        _getProductById = getProductById,
        _watchNewProducts = watchNewProducts;

  /// يجلب منتج واحد بـ docId — مُستخدم من المفضلة لجلب بيانات كاملة.
  /// يرجع null لو المنتج محذوف أو فيه خطأ شبكة.
  Future<Product?> getProductById(String docId) async {
    final res = await _getProductById(GetProductByIdParams(docId));
    return res.fold((_) => null, (p) => p);
  }

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
  String get searchQuery => _searchQuery;

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

    // اشترك بالـ real-time stream للمنتجات الجديدة بعد هذه اللحظة.
    // فأي منتج يضيفه الأدمن → يظهر فوراً في رأس القائمة.
    _subscribeToNewProducts();
  }

  /// يشترك (أو يُعيد الاشتراك) بمنتجات أُضيفت بعد الآن.
  /// يُلغي أي subscription سابق لتجنّب التسرّب.
  void _subscribeToNewProducts() {
    _newProductsSub?.cancel();
    _subscribeSince = DateTime.now();
    _newProductsSub = _watchNewProducts(WatchNewProductsParams(
      since: _subscribeSince!,
      category: _selectedCategory,
    )).listen(
      (newProducts) {
        if (newProducts.isEmpty) return;
        // ندرج فقط المنتجات اللي مش موجودة في القائمة الحالية
        final existingIds = _products
            .where((p) => p.docId != null)
            .map((p) => p.docId!)
            .toSet();
        final freshOnes = newProducts
            .where((p) =>
                p.docId != null && !existingIds.contains(p.docId))
            .toList();
        if (freshOnes.isEmpty) return;
        // freshOnes مرتّبة createdAt desc → الأحدث أولاً
        _products = [...freshOnes, ..._products];
        notifyListeners();
      },
      onError: (e) {
        // لا نُسقط الـ UI — الـ stream خفيف، أي خطأ نتجاهله
        // (المستخدم لا يزال يرى البيانات المُحمّلة عبر الـ pagination)
        debugPrint('watchNewProducts error (non-fatal): $e');
      },
    );
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

  /// يُستدعى عند signOut — تصفير كل الفلاتر والقوائم لمنع تسرّبها
  /// للحساب التالي (مثلاً: لا تبقى تصفية "أطفال" نشطة بعد signOut).
  void reset() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _newProductsSub?.cancel();
    _newProductsSub = null;
    _subscribeSince = null;
    _products = [];
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _failure = null;
    _selectedCategory = null;
    _sortMode = HomeSortMode.newArrivals;
    _lastDoc = null;
    _searchQuery = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _newProductsSub?.cancel();
    super.dispose();
  }
}

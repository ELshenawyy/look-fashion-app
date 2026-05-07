import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/models/product.dart';

/// نتيجة صفحة واحدة من المنتجات — Dart 2 متوافق (لا Record types)
class ProductPage {
  final List<Product> products;
  final DocumentSnapshot? lastDoc; // cursor للصفحة التالية — null عند التصفية بالفئة

  const ProductPage({required this.products, this.lastDoc});
}

/// مسؤولية واحدة: جلب البيانات من Firestore — لا state، لا UI
class HomeRepository {
  static const int pageSize = 10;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// جلب صفحة من المنتجات.
  ///
  /// السلوك حسب الحالة:
  /// ─ بدون فئة  → Firestore orderBy + limit (pagination حقيقي)
  /// ─ مع فئة    → where('category') فقط ثم فرز من جهة العميل
  ///               (تجنّب Composite Index الذي تتطلبه Firestore عند دمج
  ///               where + orderBy على حقلين مختلفين)
  Future<ProductPage> fetchProducts({
    String? category, // null = الكل
    String sortField = 'createdAt',
    bool descending = true,
    DocumentSnapshot? startAfter,
  }) async {
    // ── حالة: تصفية بفئة محددة ───────────────────────────────────────────
    if (category != null && category.isNotEmpty) {
      final snap = await _db
          .collection('products')
          .where('category', isEqualTo: category)
          .get();

      final docs = snap.docs.toList()
        ..sort((a, b) => _compareField(
              a.data()[sortField],
              b.data()[sortField],
              descending: descending,
            ));

      return ProductPage(
        products: docs.map(_fromDoc).toList(),
        lastDoc: null, // لا pagination عند التصفية — جميع النتائج مُعادة
      );
    }

    // ── حالة: كل المنتجات — Firestore orderBy + limit ────────────────────
    Query<Map<String, dynamic>> q = _db
        .collection('products')
        .orderBy(sortField, descending: descending)
        .limit(pageSize);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final products = snap.docs.map(_fromDoc).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    return ProductPage(products: products, lastDoc: lastDoc);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// مقارنة حقل للفرز — يدعم Timestamp، num، وأي نوع آخر
  int _compareField(dynamic a, dynamic b, {required bool descending}) {
    int cmp;
    if (a is Timestamp && b is Timestamp) {
      cmp = a.compareTo(b);
    } else if (a is num && b is num) {
      cmp = a.compareTo(b);
    } else {
      // null أو نوع غير معروف → تجاهل الترتيب
      cmp = 0;
    }
    return descending ? -cmp : cmp;
  }

  Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Product.fromJson({
      'id': 0,
      'docId': doc.id,
      'price': d['price'] ?? 0.0,
      'title': d['title'] ?? '',
      'imageUrl': d['imageUrl'] ?? '',
      'description': d['description'] ?? '',
      'gender': d['gender'] ?? '',
      'sizes': d['sizes'] ?? const <dynamic>[],
      'colors': d['colors'] ?? const <dynamic>[],
      'stockQuantity': d['stockQuantity'] ?? 0,
      'category': d['category'] ?? '',
      'state': d['state'] ?? '',
    });
  }
}

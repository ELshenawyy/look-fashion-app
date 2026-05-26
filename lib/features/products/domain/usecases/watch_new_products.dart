import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

class WatchNewProductsParams extends Equatable {
  final DateTime since;
  final String? category;
  const WatchNewProductsParams({required this.since, this.category});

  @override
  List<Object?> get props => [since, category];
}

/// Use case للاشتراك بالمنتجات المُضافة بعد timestamp مُحدَّد.
/// يُستخدَم في الشاشة الرئيسية لظهور المنتجات الجديدة فوراً
/// بدون قراءة كل الكتالوج (حفاظاً على Firestore reads).
class WatchNewProducts {
  final ProductRepository repository;
  WatchNewProducts(this.repository);

  Stream<List<Product>> call(WatchNewProductsParams params) =>
      repository.watchNewProductsSince(
        params.since,
        category: params.category,
      );
}

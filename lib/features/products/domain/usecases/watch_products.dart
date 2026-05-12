import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

class WatchProducts {
  final ProductRepository repository;
  WatchProducts(this.repository);

  Stream<List<Product>> call({String? category}) =>
      repository.watchProducts(category: category);
}

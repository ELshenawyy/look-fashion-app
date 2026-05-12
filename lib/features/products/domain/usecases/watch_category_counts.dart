import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';

class WatchCategoryCounts {
  final ProductRepository repository;
  WatchCategoryCounts(this.repository);

  Stream<Map<String, int>> call() => repository.watchCategoryCounts();
}

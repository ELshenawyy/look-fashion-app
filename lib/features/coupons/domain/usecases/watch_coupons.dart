import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class WatchCoupons {
  final CouponRepository repository;
  WatchCoupons(this.repository);

  Stream<List<CouponEntity>> call() => repository.watchCoupons();
}

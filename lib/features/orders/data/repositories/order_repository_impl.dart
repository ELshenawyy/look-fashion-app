import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remote;
  final NetworkInfo network;
  OrderRepositoryImpl({required this.remote, required this.network});

  @override
  Future<Either<Failure, String>> placeOrder(PlaceOrderInput input) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final orderId = await remote.placeOrderTransaction(input);

      // إشعار غير حرج — لا نفشل الطلب إذا فشل
      await remote.notifyAdminsOfNewOrder(
        orderId: orderId,
        userName: input.userName,
        phone: input.phone,
        userId: input.userId,
        itemNames:
            input.items.map((i) => '${i.name} x${i.quantity}').toList(),
      );

      return Right(orderId);
    } on StockException catch (e) {
      return Left(StockFailure(e.message,
          productId: e.productId, available: e.available));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<List<OrderEntity>> watchUserOrders(String userId) =>
      remote.watchUserOrders(userId);

  @override
  Stream<List<OrderEntity>> watchAllOrders() => remote.watchAllOrders();

  @override
  Future<Either<Failure, OrderEntity>> getOrderById(String orderId) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final order = await remote.getOrderById(orderId);
      return Right(order);
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? customerId,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.updateOrderStatus(
        orderId: orderId,
        status: status,
        customerId: customerId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteOrder(String orderId) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.deleteOrder(orderId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}

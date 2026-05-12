import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:my_fashion_app/core/network/network_info.dart';

// ── Features ──
import 'package:my_fashion_app/features/favorites/data/datasources/favorites_remote_datasource.dart';
import 'package:my_fashion_app/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:my_fashion_app/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/toggle_favorite.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/watch_favorite_ids.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/watch_favorites.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';

// Admin
import 'package:my_fashion_app/features/admin/data/repositories/admin_repository.dart';

// Notifications
import 'package:my_fashion_app/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:my_fashion_app/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:my_fashion_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:my_fashion_app/features/notifications/presentation/providers/notifications_provider.dart';

// Orders
import 'package:my_fashion_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:my_fashion_app/features/orders/data/repositories/order_repository_impl.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/place_order.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/update_order_status.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/watch_all_orders.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/watch_user_orders.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';

// Addresses
import 'package:my_fashion_app/features/addresses/data/datasources/address_remote_datasource.dart';
import 'package:my_fashion_app/features/addresses/data/repositories/address_repository_impl.dart';
import 'package:my_fashion_app/features/addresses/domain/repositories/address_repository.dart';
import 'package:my_fashion_app/features/addresses/presentation/providers/addresses_provider.dart';

// Cart
import 'package:my_fashion_app/features/cart/data/datasources/local_cart_datasource.dart';
import 'package:my_fashion_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:my_fashion_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart'
    as cart_p;

// Products
import 'package:my_fashion_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:my_fashion_app/features/products/data/repositories/product_repository_impl.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/features/products/domain/usecases/fetch_products_page.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_category_counts.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_products.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';

// Auth
import 'package:my_fashion_app/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:my_fashion_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_out.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/verify_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/watch_current_user.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart'
    as auth_p;

/// Service Locator العالمي.
/// استخدم `sl<T>()` لطلب أي نوع مسجَّل.
final GetIt sl = GetIt.instance;

/// تُستدعى مرة واحدة من main() قبل runApp.
Future<void> init() async {
  // ─── External (Firebase + System) ───────────────────────────────────────
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // ─── Core ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // ─── Features ───────────────────────────────────────────────────────────
  _initAuth();
  _initProducts();
  _initCart();
  _initOrders();
  _initNotifications();
  _initAddresses();
  _initFavorites();
  _initAdmin();
}

void _initAdmin() {
  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepository(sl(), sl()),
  );
}

void _initNotifications() {
  sl.registerLazySingleton(() => NotificationsProvider(sl()));
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remote: sl(), network: sl()),
  );
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(sl()),
  );
}

void _initOrders() {
  sl.registerLazySingleton(() => OrdersProvider(
        placeOrder: sl(),
        watchUserOrders: sl(),
        watchAllOrders: sl(),
        updateOrderStatus: sl(),
      ));

  sl.registerLazySingleton(() => PlaceOrder(sl()));
  sl.registerLazySingleton(() => WatchUserOrders(sl()));
  sl.registerLazySingleton(() => WatchAllOrders(sl()));
  sl.registerLazySingleton(() => UpdateOrderStatus(sl()));
  sl.registerLazySingleton(() => GetOrderById(sl()));

  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(remote: sl(), network: sl()),
  );
  sl.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(sl()),
  );
}

void _initAddresses() {
  sl.registerFactory(() => AddressesProvider(sl()));
  sl.registerLazySingleton<AddressRepository>(
    () => AddressRepositoryImpl(remote: sl(), network: sl()),
  );
  sl.registerLazySingleton<AddressRemoteDataSource>(
    () => AddressRemoteDataSourceImpl(sl()),
  );
}

void _initCart() {
  // Singleton: السلة state عالمي مشترك
  sl.registerLazySingleton(() => cart_p.CartProvider(sl()));

  sl.registerLazySingleton<CartRepository>(
    () => CartRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => LocalCartDataSource());
}

void _initProducts() {
  sl.registerFactory(() => ProductsProvider(fetchProductsPage: sl()));
  sl.registerFactory(() => CategoriesProvider(watchCategoryCounts: sl()));

  sl.registerLazySingleton(() => FetchProductsPage(sl()));
  sl.registerLazySingleton(() => WatchCategoryCounts(sl()));
  sl.registerLazySingleton(() => WatchProducts(sl()));

  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(remote: sl(), network: sl()),
  );

  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(sl()),
  );
}

void _initAuth() {
  // Provider — singleton لأنه يحمل state عالمي (المستخدم الحالي)
  sl.registerLazySingleton(() => auth_p.AuthProvider(
        watchCurrentUser: sl(),
        signInWithEmail: sl(),
        signUpWithEmail: sl(),
        sendOtp: sl(),
        verifyOtp: sl(),
        sendPasswordReset: sl(),
        signOut: sl(),
      ));

  // Use Cases
  sl.registerLazySingleton(() => WatchCurrentUser(sl()));
  sl.registerLazySingleton(() => SignInWithEmail(sl()));
  sl.registerLazySingleton(() => SignUpWithEmail(sl()));
  sl.registerLazySingleton(() => SendOtp(sl()));
  sl.registerLazySingleton(() => VerifyOtp(sl()));
  sl.registerLazySingleton(() => SendPasswordReset(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remote: sl(), network: sl(), db: sl()),
  );

  // Data Source
  sl.registerLazySingleton<FirebaseAuthDataSource>(
    () => FirebaseAuthDataSourceImpl(sl(), sl()),
  );
}

void _initFavorites() {
  // Provider — factory: instance جديد لكل screen mount
  sl.registerFactory(() => FavoritesProvider(
        toggleFavorite: sl(),
        watchFavoriteIds: sl(),
        watchFavorites: sl(),
      ));

  // Use Cases
  sl.registerLazySingleton(() => ToggleFavorite(sl()));
  sl.registerLazySingleton(() => WatchFavoriteIds(sl()));
  sl.registerLazySingleton(() => WatchFavorites(sl()));

  // Repository
  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(remote: sl(), network: sl()),
  );

  // Data Source
  sl.registerLazySingleton<FavoritesRemoteDataSource>(
    () => FavoritesRemoteDataSourceImpl(sl()),
  );
}

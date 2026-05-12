import 'package:equatable/equatable.dart';

/// كل الأخطاء في طبقة domain ترجع كـ Failure (لا exceptions تطفو لـ UI).
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال بالإنترنت']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'ليس لديك صلاحية لهذه العملية']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'العنصر المطلوب غير موجود']);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'حدث خطأ غير متوقع']);
}

/// خاص بمشاكل المخزون عند placeOrder
class StockFailure extends Failure {
  final String productId;
  final int available;

  const StockFailure(
    super.message, {
    required this.productId,
    required this.available,
  });

  @override
  List<Object?> get props => [message, productId, available];
}

/// مساعد لتحويل Failure لرسالة عربية للعرض في UI
String failureToMessage(Failure f) => f.message;

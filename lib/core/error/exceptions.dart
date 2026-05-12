// Exceptions تُرمى من Data Sources وتُلتقط في Repository Implementations
// لتُحوَّل إلى Failures.

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No internet connection']);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class StockException implements Exception {
  final String message;
  final String productId;
  final int available;
  const StockException(
    this.message, {
    required this.productId,
    required this.available,
  });
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Not found']);
}

class PermissionException implements Exception {
  final String message;
  const PermissionException([this.message = 'Permission denied']);
}

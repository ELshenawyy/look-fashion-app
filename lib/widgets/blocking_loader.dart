import 'package:flutter/material.dart';

/// يعرض overlay يحجب التفاعل ويُظهر spinner + رسالة اختيارية.
/// يُغلق تلقائياً في `finally` حتى لو الـ action رمى exception.
///
/// مثال:
/// ```dart
/// final result = await runWithBlockingLoader<Product?>(
///   context: context,
///   action: () => provider.getProductById(docId),
///   message: 'جاري تحميل المنتج...',
/// );
/// ```
Future<T> runWithBlockingLoader<T>({
  required BuildContext context,
  required Future<T> Function() action,
  String? message,
}) async {
  const gold = Color(0xFFD4AF37);
  const panel = Color(0xFF180808);

  // اعرض overlay غير قابل للإغلاق
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 28,
            vertical: message == null ? 18 : 24,
          ),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                    color: gold, strokeWidth: 3),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await action();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

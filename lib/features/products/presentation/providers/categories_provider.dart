import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_category_counts.dart';

/// Provider يدير stream لعدد المنتجات في كل فئة + auto-retry عند الفشل.
class CategoriesProvider extends ChangeNotifier {
  final WatchCategoryCounts _watchCategoryCounts;

  CategoriesProvider({required WatchCategoryCounts watchCategoryCounts})
      : _watchCategoryCounts = watchCategoryCounts {
    _start();
  }

  StreamSubscription<Map<String, int>>? _sub;
  Timer? _retryTimer;
  Map<String, int> _counts = const {};
  bool _loading = true;
  Object? _error;
  int _retryAttempt = 0;
  static const int _maxAutoRetries = 3;

  Map<String, int> get counts => _counts;
  bool get loading => _loading;
  Object? get error => _error;

  void _start() {
    _retryTimer?.cancel();
    _sub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();

    _sub = _watchCategoryCounts().listen(
      (data) {
        _counts = data;
        _loading = false;
        _error = null;
        _retryAttempt = 0; // أعد العداد عند النجاح
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        // ── Auto-retry بـ exponential backoff ──
        // الأخطاء عادةً عابرة (انقطاع شبكة لحظي / token refresh).
        // 3 محاولات تلقائية قبل إظهار خطأ للمستخدم.
        if (_retryAttempt < _maxAutoRetries) {
          _retryAttempt++;
          final delay = Duration(seconds: 1 << _retryAttempt); // 2,4,8s
          if (kDebugMode) {
            debugPrint(
                '[CategoriesProvider] error → auto-retry $_retryAttempt/$_maxAutoRetries in ${delay.inSeconds}s');
          }
          _retryTimer = Timer(delay, () {
            if (_sub == null) return; // تم cancel من الخارج
            _start();
          });
        } else {
          _error = e;
          notifyListeners();
        }
      },
    );
  }

  /// إعادة محاولة يدوية من زر "إعادة المحاولة".
  void retry() {
    _retryAttempt = 0;
    _start();
  }

  /// تصفير عند signOut. لا نُعيد التشغيل تلقائياً — ننتظر أول consumer
  /// (الشاشة) ليطلب البيانات بعد تسجيل الدخول الجديد.
  void reset() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _sub?.cancel();
    _sub = null;
    _counts = const {};
    _loading = false;
    _error = null;
    _retryAttempt = 0;
    notifyListeners();
  }

  /// يُستدعى من categories_screen في initState — يبدأ الـ stream إذا كان
  /// متوقفاً (بعد reset). إن كان شغّالاً، لا يفعل شيئاً.
  void ensureStarted() {
    if (_sub == null) _start();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

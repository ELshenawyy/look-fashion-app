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
  // ⚠ لا حد أقصى للمحاولات. الأخطاء على Firestore stream عادةً عابرة
  // (cold start, token refresh, شبكة لحظية). نواصل المحاولة بصمت
  // مع capped delay، ولا نُظهر error للمستخدم إلا في حالة شديدة جداً.
  static const int _maxRetryDelaySec = 4;

  Map<String, int> get counts => _counts;
  bool get loading => _loading;
  Object? get error => _error;

  void _start() {
    _retryTimer?.cancel();
    _sub?.cancel();
    // نُبقي _loading=true طوال محاولة الاتصال — المستخدم يرى shimmer
    // بدلاً من error screen أثناء الـ cold start.
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
        // لا نوقف الـ loading state — نواصل المحاولة بصمت.
        // المستخدم يبقى يرى shimmer، لا error screen.
        _retryAttempt++;
        // exponential backoff مع cap عند 4 ثوان (1, 2, 4, 4, 4...)
        final delaySec =
            (1 << _retryAttempt).clamp(1, _maxRetryDelaySec);
        if (kDebugMode) {
          debugPrint(
              '[CategoriesProvider] stream error #$_retryAttempt → silent retry in ${delaySec}s: $e');
        }
        _retryTimer = Timer(Duration(seconds: delaySec), () {
          if (_sub == null) return; // تم cancel من الخارج
          _start();
        });
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_category_counts.dart';

/// Provider بسيط يدير stream لعدد المنتجات في كل فئة.
class CategoriesProvider extends ChangeNotifier {
  final WatchCategoryCounts _watchCategoryCounts;
  CategoriesProvider({required WatchCategoryCounts watchCategoryCounts})
      : _watchCategoryCounts = watchCategoryCounts {
    _start();
  }

  StreamSubscription<Map<String, int>>? _sub;
  Map<String, int> _counts = const {};
  bool _loading = true;
  Object? _error;

  Map<String, int> get counts => _counts;
  bool get loading => _loading;
  Object? get error => _error;

  void _start() {
    _sub?.cancel();
    _sub = _watchCategoryCounts().listen(
      (data) {
        _counts = data;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e;
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

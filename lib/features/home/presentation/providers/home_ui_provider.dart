import 'package:flutter/foundation.dart';

/// UI state محلي لـ HomeScreen / ProductListScreen.
///
/// يحتوي على transient UI state (مش business state):
/// - `isListening`: حالة voice search (mic icon)
/// - `bannerIndex`: الـ page index للـ banner carousel (يُستخدم
///   لتمييز الـ active dot في الـ indicator)
///
/// إخراج هذا الـ state من `setState` يجعل الـ widget tree أنظف
/// وأكثر قابلية للاختبار، ويتماشى مع نمط Provider/ChangeNotifier
/// المستخدم في باقي المشروع.
class HomeUIProvider extends ChangeNotifier {
  bool _isListening = false;
  int _bannerIndex = 0;

  bool get isListening => _isListening;
  int get bannerIndex => _bannerIndex;

  void setListening(bool value) {
    if (_isListening == value) return;
    _isListening = value;
    notifyListeners();
  }

  void setBannerIndex(int index) {
    if (_bannerIndex == index) return;
    _bannerIndex = index;
    notifyListeners();
  }
}

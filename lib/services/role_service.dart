import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة مركزية للصلاحيات — كل الكود يستورد منطق الأدوار من هنا.
///
/// الأدوار المتاحة:
///   superAdmin — صلاحية كاملة (إضافة، تعديل، حذف، إدارة موظفين)
///   subAdmin   — إضافة وتعديل المنتجات ورؤية الطلبات فقط (لا حذف)
///   user       — مستخدم عادي (عميل)
abstract class AppRole {
  static const String superAdmin = 'superAdmin';
  static const String subAdmin = 'subAdmin';
  static const String user = 'user';

  /// superAdmin أو subAdmin — له صلاحية الدخول للوحة الإدارة
  static bool isAdminLevel(String? role) =>
      role == superAdmin || role == subAdmin;

  /// superAdmin فقط
  static bool isSuperAdmin(String? role) => role == superAdmin;

  /// قراءة دور المستخدم الحالي من Firestore (one-shot)
  static Future<String> currentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return user;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['role'] as String? ?? user;
  }
}

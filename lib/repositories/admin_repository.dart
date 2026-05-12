import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_fashion_app/services/role_service.dart';

/// نتيجة البحث عن مستخدم في Firestore
class AdminUserResult {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;

  const AdminUserResult({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });
}

/// Repository مسؤول عن عمليات إدارة الأدوار (RBAC) في Firestore.
/// يفصل منطق قاعدة البيانات عن الـ UI.
class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── البحث عن مستخدم بالبريد الإلكتروني أو رقم الهاتف ──────────────────
  Future<AdminUserResult?> findUserByEmailOrPhone(String identifier) async {
    try {
      final trimmed = identifier.trim();

      // ── بريد إلكتروني ──
      if (trimmed.contains('@')) {
        final snap = await _db
            .collection('users')
            .where('email', isEqualTo: trimmed.toLowerCase())
            .limit(1)
            .get();
        return snap.docs.isEmpty ? null : _fromDoc(snap.docs.first);
      }

      // ── رقم هاتف — تطبيع الرقم ──
      final phone = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // محاولة البحث المباشر أولاً
      final direct = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (direct.docs.isNotEmpty) return _fromDoc(direct.docs.first);

      // إذا كان رقم محلي سوداني (09XXXXXXXX) → نحوّله لـ +249
      if (phone.startsWith('09') && phone.length == 10) {
        final intl = '+249${phone.substring(1)}';
        final intlSnap = await _db
            .collection('users')
            .where('phone', isEqualTo: intl)
            .limit(1)
            .get();
        if (intlSnap.docs.isNotEmpty) return _fromDoc(intlSnap.docs.first);
      }

      // إذا كان بدون + (مثلاً 249XXXXXXXXX)
      if (phone.startsWith('249') && phone.length == 12) {
        final withPlus = '+$phone';
        final plusSnap = await _db
            .collection('users')
            .where('phone', isEqualTo: withPlus)
            .limit(1)
            .get();
        if (plusSnap.docs.isNotEmpty) return _fromDoc(plusSnap.docs.first);
      }

      return null;
    } on FirebaseException catch (e) {
      throw Exception('خطأ في البحث: ${_mapFirestoreError(e.code)}');
    } catch (_) {
      throw Exception('خطأ غير متوقع أثناء البحث، تحقق من الاتصال');
    }
  }

  // ── ترقية مستخدم إلى subAdmin ──────────────────────────────────────────
  Future<void> promoteToSubAdmin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'role': AppRole.subAdmin,
        'promotedAt': FieldValue.serverTimestamp(),
        'revokedAt': FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      throw Exception('فشل الترقية: ${_mapFirestoreError(e.code)}');
    } catch (_) {
      throw Exception('خطأ غير متوقع أثناء الترقية');
    }
  }

  // ── إلغاء صلاحيات الموظف ────────────────────────────────────────────────
  Future<void> revokeAdmin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'role': AppRole.user,
        'revokedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('فشل إلغاء الصلاحيات: ${_mapFirestoreError(e.code)}');
    } catch (_) {
      throw Exception('خطأ غير متوقع أثناء إلغاء الصلاحيات');
    }
  }

  // ── حذف منتج مع صورته من Storage ────────────────────────────────────────
  Future<void> deleteProduct(String docId, {String imageUrl = ''}) async {
    try {
      await _db.collection('products').doc(docId).delete();

      if (imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (_) {
          // صورة الـ Storage اختيارية — لا نوقف العملية إن فشل حذفها
        }
      }
    } on FirebaseException catch (e) {
      throw Exception('فشل حذف المنتج: ${_mapFirestoreError(e.code)}');
    } catch (_) {
      throw Exception('خطأ غير متوقع أثناء حذف المنتج');
    }
  }

  // ── تحويل Document إلى AdminUserResult ──────────────────────────────────
  AdminUserResult _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminUserResult(
      uid: doc.id,
      name: d['name'] as String? ?? 'مستخدم',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      role: d['role'] as String? ?? AppRole.user,
    );
  }

  // ── تحويل كودات Firestore إلى رسائل عربية ───────────────────────────────
  String _mapFirestoreError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'ليس لديك صلاحية لهذه العملية';
      case 'not-found':
        return 'المستخدم أو المستند غير موجود';
      case 'unavailable':
        return 'الخدمة غير متاحة حالياً، تحقق من الاتصال بالإنترنت';
      case 'deadline-exceeded':
        return 'انتهت مهلة الطلب، حاول مرة أخرى';
      case 'already-exists':
        return 'البيانات موجودة مسبقاً';
      default:
        return 'حدث خطأ ($code)';
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_role.dart';

/// نتيجة البحث عن مستخدم في Firestore (للوحة إدارة الموظفين).
class AdminUserResult {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool emailVerified;

  const AdminUserResult({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.emailVerified = true,
  });
}

/// Repository لعمليات الإدمن (RBAC + إدارة المنتجات).
/// مُسجَّل في DI كـ singleton.
class AdminRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  AdminRepository(this._db, this._storage);

  Future<AdminUserResult?> findUserByEmailOrPhone(String identifier) async {
    try {
      final trimmed = identifier.trim();

      if (trimmed.contains('@')) {
        final snap = await _db
            .collection('users')
            .where('email', isEqualTo: trimmed.toLowerCase())
            .limit(1)
            .get();
        return snap.docs.isEmpty ? null : _fromDoc(snap.docs.first);
      }

      final phone = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      final direct = await _db
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (direct.docs.isNotEmpty) return _fromDoc(direct.docs.first);

      if (phone.startsWith('09') && phone.length == 10) {
        final intl = '+249${phone.substring(1)}';
        final intlSnap = await _db
            .collection('users')
            .where('phone', isEqualTo: intl)
            .limit(1)
            .get();
        if (intlSnap.docs.isNotEmpty) return _fromDoc(intlSnap.docs.first);
      }

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
    } catch (e, st) {
      debugPrint('AdminRepository.findUserByEmailOrPhone error: $e\n$st');
      throw Exception('خطأ غير متوقع أثناء البحث، تحقق من الاتصال');
    }
  }

  Future<void> promoteToSubAdmin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'role': UserRole.subAdmin.toFirestoreValue(),
        'promotedAt': FieldValue.serverTimestamp(),
        'revokedAt': FieldValue.delete(),
        // إعادة تعيين موظف محظور سابقاً → رفع الحظر
        'banned': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      throw Exception('فشل الترقية: ${_mapFirestoreError(e.code)}');
    } catch (e, st) {
      debugPrint('AdminRepository.promoteToSubAdmin error: $e\n$st');
      throw Exception('خطأ غير متوقع أثناء الترقية');
    }
  }

  /// طرد موظف وحظره نهائياً من استخدام التطبيق:
  /// - تنزيل دوره إلى مستخدم عادي
  /// - تعيين banned=true → يمنع تسجيل الدخول مرة أخرى ويطرده فوراً
  ///   من أي جلسة نشطة (راجع AuthProvider.isBanned)
  Future<void> revokeAdmin(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'role': UserRole.customer.toFirestoreValue(),
        'revokedAt': FieldValue.serverTimestamp(),
        'banned': true,
        'bannedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('فشل إلغاء الصلاحيات: ${_mapFirestoreError(e.code)}');
    } catch (e, st) {
      debugPrint('AdminRepository.revokeAdmin error: $e\n$st');
      throw Exception('خطأ غير متوقع أثناء إلغاء الصلاحيات');
    }
  }

  Future<void> deleteProduct(String docId, {List<String> imageUrls = const []}) async {
    try {
      await _db.collection('products').doc(docId).delete();

      for (final url in imageUrls) {
        if (url.isEmpty) continue;
        try {
          await _storage.refFromURL(url).delete();
        } catch (e) {
          debugPrint('Storage image delete failed (non-fatal): $e');
        }
      }
    } on FirebaseException catch (e) {
      throw Exception('فشل حذف المنتج: ${_mapFirestoreError(e.code)}');
    } catch (e, st) {
      debugPrint('AdminRepository.deleteProduct error: $e\n$st');
      throw Exception('خطأ غير متوقع أثناء حذف المنتج');
    }
  }

  AdminUserResult _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final email = d['email'] as String? ?? '';
    // مستخدمو الهاتف (بدون email) دايماً مفعّلون عبر OTP
    final emailVerified = email.isEmpty
        ? true
        : (d['emailVerified'] as bool? ?? false);
    return AdminUserResult(
      uid: doc.id,
      name: d['name'] as String? ?? 'مستخدم',
      email: email,
      phone: d['phone'] as String? ?? '',
      role: d['role'] as String? ?? UserRole.customer.toFirestoreValue(),
      emailVerified: emailVerified,
    );
  }

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

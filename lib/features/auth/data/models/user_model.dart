import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_role.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    super.email,
    super.phone,
    super.displayName,
    super.photoUrl,
    super.role,
    super.emailVerified,
    super.createdAt,
    super.revokedAt,
  });

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool emailVerified = false,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      displayName: data['name'] as String? ?? data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String? ?? data['avatar'] as String?,
      role: UserRole.fromString(data['role'] as String?),
      emailVerified: emailVerified,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      revokedAt: (data['revokedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// مستند جديد عند التسجيل — يفرض role='user'
  static Map<String, dynamic> initialFirestoreDoc({
    required String uid,
    required String email,
    required String name,
  }) =>
      {
        'uid': uid,
        'email': email,
        'name': name,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      };
}

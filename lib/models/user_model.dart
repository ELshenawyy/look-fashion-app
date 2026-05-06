import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات المستخدم — يدعم ثلاثة أدوار:
/// 'superAdmin' | 'subAdmin' | 'user'
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime? createdAt;
  final DateTime? revokedAt; // إن وُجد → يتم الطرد الفوري من التطبيق

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.role = 'user',
    this.createdAt,
    this.revokedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String? ?? '',
        name: map['name'] as String? ?? '',
        role: map['role'] as String? ?? 'user',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        revokedAt: (map['revokedAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
      };
}

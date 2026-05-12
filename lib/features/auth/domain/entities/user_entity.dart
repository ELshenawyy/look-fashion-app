import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_role.dart';

/// كيان المستخدم — لا اعتماد على Firebase.
class UserEntity extends Equatable {
  final String uid;
  final String? email;
  final String? phone;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? revokedAt; // إذا كان != null → الحساب مُلغى

  const UserEntity({
    required this.uid,
    this.email,
    this.phone,
    this.displayName,
    this.photoUrl,
    this.role = UserRole.customer,
    this.createdAt,
    this.revokedAt,
  });

  bool get isRevoked => revokedAt != null;
  bool get isAdmin => role.isAdminLevel;
  bool get isSuperAdmin => role.isSuperAdmin;

  @override
  List<Object?> get props => [
        uid,
        email,
        phone,
        displayName,
        photoUrl,
        role,
        createdAt,
        revokedAt,
      ];
}

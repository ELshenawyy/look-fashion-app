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
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? revokedAt; // إذا كان != null → الحساب مُلغى

  /// `true` فقط عندما تكون كل البيانات مقروءة من Firestore (الدور صحيح).
  /// `false` يعني تسجيل دخول حدث في FirebaseAuth لكن مستند users/ لم
  /// يحمَّل بعد — لا يجب الاعتماد على `role` في هذه الحالة.
  final bool isLoaded;

  const UserEntity({
    required this.uid,
    this.email,
    this.phone,
    this.displayName,
    this.photoUrl,
    this.role = UserRole.customer,
    this.emailVerified = false,
    this.createdAt,
    this.revokedAt,
    this.isLoaded = true,
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
        emailVerified,
        createdAt,
        revokedAt,
        isLoaded,
      ];
}

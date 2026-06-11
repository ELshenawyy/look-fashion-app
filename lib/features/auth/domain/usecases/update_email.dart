import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class UpdateEmailParams extends Equatable {
  final String currentPassword;
  final String newEmail;
  const UpdateEmailParams({
    required this.currentPassword,
    required this.newEmail,
  });

  @override
  List<Object?> get props => [currentPassword, newEmail];
}

/// يبدأ تحديث البريد الإلكتروني للمستخدم الحالي.
/// 1) reauthenticate بكلمة المرور الحالية
/// 2) يرسل رابط تأكيد للبريد الجديد
/// 3) عند ضغط الرابط من البريد الجديد → Firebase يحدّث الإيميل
class UpdateEmail implements UseCase<void, UpdateEmailParams> {
  final AuthRepository repository;
  UpdateEmail(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateEmailParams params) =>
      repository.updateEmail(
        currentPassword: params.currentPassword,
        newEmail: params.newEmail,
      );
}

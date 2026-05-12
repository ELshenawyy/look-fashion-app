import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class WatchCurrentUser {
  final AuthRepository repository;
  WatchCurrentUser(this.repository);

  Stream<UserEntity?> call() => repository.watchCurrentUser();
}

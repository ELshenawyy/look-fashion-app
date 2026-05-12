import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';

/// كل use case يطبّق هذه الواجهة:
///   call(params) → Either<Failure, T>
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// لـ use cases بدون params
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}

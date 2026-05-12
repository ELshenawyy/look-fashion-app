import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/addresses/domain/entities/address_entity.dart';
import 'package:my_fashion_app/features/addresses/domain/repositories/address_repository.dart';

class AddressesProvider extends ChangeNotifier {
  final AddressRepository _repo;
  AddressesProvider(this._repo);

  StreamSubscription<List<AddressEntity>>? _sub;
  List<AddressEntity> _addresses = const [];
  Failure? _failure;
  bool _loading = true;
  String? _activeUserId;

  List<AddressEntity> get addresses => _addresses;
  Failure? get failure => _failure;
  bool get loading => _loading;

  void startWatching(String userId) {
    if (_activeUserId == userId && _sub != null) return;
    _activeUserId = userId;
    _sub?.cancel();
    _sub = _repo.watchAddresses(userId).listen(
      (data) {
        _addresses = data;
        _loading = false;
        _failure = null;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> add({
    required String userId,
    required String label,
    required String region,
    required String street,
    required String building,
  }) async {
    final res = await _repo.addAddress(
      userId: userId,
      label: label,
      region: region,
      street: street,
      building: building,
    );
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  Future<bool> delete({
    required String userId,
    required String addressId,
  }) async {
    final res = await _repo.deleteAddress(userId: userId, addressId: addressId);
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

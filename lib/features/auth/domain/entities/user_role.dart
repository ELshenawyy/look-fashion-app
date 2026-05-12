/// الأدوار المتاحة في النظام.
/// كائن نقي — لا اعتماد على Firebase أو Firestore.
enum UserRole {
  customer,
  subAdmin,
  superAdmin;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'superAdmin':
        return UserRole.superAdmin;
      case 'subAdmin':
        return UserRole.subAdmin;
      default:
        return UserRole.customer;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case UserRole.superAdmin:
        return 'superAdmin';
      case UserRole.subAdmin:
        return 'subAdmin';
      case UserRole.customer:
        return 'user';
    }
  }

  bool get isAdminLevel =>
      this == UserRole.superAdmin || this == UserRole.subAdmin;
  bool get isSuperAdmin => this == UserRole.superAdmin;
}

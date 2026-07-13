import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/phone_number.dart';

/// يتحقق فعلياً من أن طول الرقم مناسب لدولته المختارة (عبر
/// isValidNumber() من intl_phone_field)، بدل الاكتفاء بفحص أن الرقم
/// يبدأ بـ "+" فقط. الفحص القديم كان يسمح بمرور أرقام بعدد خانات
/// خاطئ لدولتها، فتُقبل من Firebase وتُرسل لها SMS لا يصل لأي مشترك حقيقي.
bool isValidPhoneNumber(PhoneNumber phone) {
  if (phone.number.isEmpty) return false;
  try {
    return phone.isValidNumber();
  } catch (_) {
    return false;
  }
}

/// نفس الفحص لكن انطلاقاً من Country + الرقم القومي مباشرة — يُستخدم
/// لإعادة التحقق فوراً عند تغيير الدولة (onCountryChanged) قبل أن
/// يكتب المستخدم أي رقم جديد.
bool isValidPhoneForCountry(Country country, String nationalNumber) {
  return isValidPhoneNumber(PhoneNumber(
    countryISOCode: country.code,
    countryCode: '+${country.fullCountryCode}',
    number: nationalNumber,
  ));
}

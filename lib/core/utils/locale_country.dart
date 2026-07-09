import 'package:flutter/widgets.dart';
import 'package:intl_phone_field/countries.dart';

/// رمز الدولة الافتراضي لو تعذّر استنتاج دولة الجهاز.
const String kFallbackPhoneCountryCode = 'SD';

/// يحدّد رمز الدولة (ISO) الافتراضي لحقل رقم الهاتف بناءً على منطقة
/// الجهاز، بدلاً من افتراض السودان لكل المستخدمين بغض النظر عن
/// موقعهم الفعلي. يرجع [kFallbackPhoneCountryCode] فقط لو تعذّر
/// استنتاج دولة الجهاز أو كانت غير مدعومة في intl_phone_field.
String defaultPhoneCountryCode(BuildContext context) {
  final deviceCountry = Localizations.maybeLocaleOf(context)?.countryCode;
  if (deviceCountry == null || deviceCountry.isEmpty) {
    return kFallbackPhoneCountryCode;
  }
  final upper = deviceCountry.toUpperCase();
  final isSupported = countries.any((c) => c.code == upper);
  return isSupported ? upper : kFallbackPhoneCountryCode;
}

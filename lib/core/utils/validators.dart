/// أدوات تحقق مشتركة للنماذج (زبائن/موردين/إلخ)
class Validators {
  /// رقم هاتف سوري محلي: 10 أرقام بالضبط، يبدأ بـ 09
  static final RegExp syrianPhoneRegex = RegExp(r'^09\d{8}$');

  /// إلزامي + يجب أن يكون رقماً صحيحاً (10 أرقام، يبدأ بـ 09)
  static String? requiredPhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'رقم الهاتف إلزامي';
    if (!syrianPhoneRegex.hasMatch(v)) {
      return 'رقم غير صحيح (10 أرقام تبدأ بـ 09)';
    }
    return null;
  }
}

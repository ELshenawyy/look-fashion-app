import 'package:flutter/material.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          AppSliverBar(
            title: 'سياسة الخصوصية',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _section(
                  'جمع البيانات',
                  'نقوم بجمع المعلومات التي تقدمها لنا عند التسجيل أو الشراء، '
                  'مثل الاسم وعنوان البريد الإلكتروني ورقم الهاتف وعنوان التوصيل. '
                  'نستخدم هذه البيانات حصراً لمعالجة طلباتك وتحسين تجربتك في التطبيق.',
                ),
                _section(
                  'استخدام البيانات',
                  'تُستخدم بياناتك الشخصية لإتمام عمليات الشراء، وإرسال إشعارات '
                  'حالة الطلب، وتقديم الدعم الفني. لا نبيع بياناتك لأي طرف ثالث '
                  'ولا نشاركها إلا مع مزودي الخدمة الضروريين لتشغيل التطبيق.',
                ),
                _section(
                  'الأمان',
                  'نستخدم تقنيات تشفير متقدمة لحماية بياناتك. جميع معاملاتك تتم '
                  'عبر اتصالات آمنة (HTTPS). كلمات المرور مشفرة ولا يمكن لأي موظف '
                  'الاطلاع عليها.',
                ),
                _section(
                  'ملفات تعريف الارتباط',
                  'قد يستخدم التطبيق تقنيات مشابهة لتحسين الأداء وتذكر تفضيلاتك. '
                  'يمكنك إيقاف هذه التقنيات من إعدادات جهازك، مع العلم أن بعض '
                  'الميزات قد لا تعمل بشكل كامل.',
                ),
                _section(
                  'حقوقك',
                  'يحق لك طلب الاطلاع على بياناتك الشخصية وتعديلها أو حذفها في '
                  'أي وقت. يمكنك التواصل معنا عبر البريد الإلكتروني أو واتساب '
                  'لممارسة هذه الحقوق.',
                ),
                _section(
                  'التحديثات',
                  'قد نحدّث سياسة الخصوصية هذه من وقت لآخر. سنخطرك بأي تغييرات '
                  'جوهرية عبر إشعار داخل التطبيق.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'آخر تحديث: مايو 2025',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _section(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

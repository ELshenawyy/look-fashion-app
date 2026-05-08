import 'package:flutter/material.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          AppSliverBar(
            title: 'الشروط والأحكام',
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
                  'القبول بالشروط',
                  'باستخدامك لتطبيق طلّة، فإنك توافق على الالتزام بهذه الشروط '
                  'والأحكام. إذا كنت لا توافق على أي من هذه الشروط، يرجى التوقف '
                  'عن استخدام التطبيق.',
                ),
                _section(
                  'استخدام التطبيق',
                  'يُسمح باستخدام التطبيق للأغراض الشخصية وغير التجارية فقط. '
                  'يُحظر استخدام التطبيق لأي غرض غير مشروع أو بطريقة تنتهك '
                  'حقوق الآخرين أو تُلحق الضرر بالخدمة.',
                ),
                _section(
                  'الطلبات والدفع',
                  'جميع الأسعار معروضة بالجنيه السوداني (ج.س). يُعدّ الطلب '
                  'مؤكداً فقط بعد استلام رسالة تأكيد من فريق المتجر. نحتفظ بحق '
                  'رفض أي طلب لأسباب مشروعة.',
                ),
                _section(
                  'الشحن والتوصيل',
                  'مدة التوصيل من 1 إلى 15 يوم عمل حسب الولاية. تختلف رسوم '
                  'التوصيل بين الشحن المحلي (داخل الولاية) والشحن بين الولايات. '
                  'لسنا مسؤولين عن التأخيرات الناجمة عن ظروف خارجة عن إرادتنا.',
                ),
                _section(
                  'الإرجاع والاستبدال',
                  'يمكن طلب الإرجاع أو الاستبدال خلال 7 أيام من استلام المنتج، '
                  'شريطة أن يكون المنتج في حالته الأصلية وغير مستخدم. يتحمل '
                  'العميل رسوم إعادة الشحن في حالة الإرجاع غير المبرر.',
                ),
                _section(
                  'الملكية الفكرية',
                  'جميع المحتويات الموجودة في التطبيق من صور وشعارات ونصوص هي '
                  'ملك حصري لمتجر طلّة. لا يجوز نسخها أو توزيعها أو استخدامها '
                  'بدون إذن كتابي مسبق.',
                ),
                _section(
                  'تعديل الشروط',
                  'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. ستُعلَم بالتغييرات '
                  'الجوهرية عبر إشعار داخل التطبيق. استمرارك في استخدام التطبيق '
                  'بعد التعديل يُعدّ قبولاً للشروط الجديدة.',
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

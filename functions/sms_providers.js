/**
 * طبقة إرسال SMS قابلة للتبديل — بدون أي dependencies (fetch مدمج في Node 20).
 *
 * ⭐ المزوّد الوحيد المُفعَّل حالياً: WhatsApp Cloud API (SMS_PROVIDER_PRIMARY في
 * .env). كل المزوّدين الدوليين البديلين (textbee / Unimatrix / CheapGlobalSMS /
 * BudgetSMS) فشلوا فعلياً في التوصيل للسودان أو لم يُهيَّأوا أبداً، وتمت
 * إزالتهم من الكود. راجع Git history لو احتجت استرجاع أيٍّ منهم مستقبلاً.
 *
 * التبديل بين المزوّدين = تغيير SMS_PROVIDER_PRIMARY / SMS_PROVIDER_FALLBACK
 * (env params) بدون أي تعديل كود. مفاتيح كل مزوّد تُقرأ من process.env —
 * تُضبط كـ Secrets في index.js (انظر تعليقات كل مزوّد لأسماء المفاتيح).
 */

/** يبني نص رسالة الكود — لاتيني/GSM-7 (مقطع واحد، أوسع توافق). */
function otpMessage(code) {
  return `Tala LOOK verification code: ${code}`;
}

/** WhatsApp Cloud API — إرسال كود OTP كرسالة قالب "Authentication".
 *  https://developers.facebook.com/docs/whatsapp/cloud-api — يعمل في السودان
 *  100% (إنترنت، يتجاوز مشكلة توصيل الـ SMS تماماً).
 *  Secrets: WHATSAPP_PHONE_NUMBER_ID + WHATSAPP_ACCESS_TOKEN.
 *  Config (env): WHATSAPP_TEMPLATE_NAME (اسم القالب المعتمد) +
 *  WHATSAPP_TEMPLATE_LANG (لغته، مثل ar / en_US).
 *  الأرقام: بصيغة دولية بدون + (مثال: 249922221567). */
async function sendViaWhatsapp(phone, text, code) {
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  const template = process.env.WHATSAPP_TEMPLATE_NAME;
  const lang = process.env.WHATSAPP_TEMPLATE_LANG || 'ar';
  if (!phoneNumberId || !token || !template) {
    throw new Error('whatsapp: WHATSAPP_PHONE_NUMBER_ID/ACCESS_TOKEN/TEMPLATE_NAME not configured');
  }
  // قالب المصادقة القياسي في Meta: الكود يُمرَّر في متغيّر النص (body) وفي
  // زرّ "نسخ الكود" (copy-code button). إن كان قالبك بدون زر، احذف عنصر
  // button — لكن قوالب Meta الجاهزة للـ Authentication تتضمّنه افتراضياً.
  const res = await fetch(
    `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: phone.replace(/^\+/, ''),
        type: 'template',
        template: {
          name: template,
          language: { code: lang },
          components: [
            { type: 'body', parameters: [{ type: 'text', text: code }] },
            {
              type: 'button',
              sub_type: 'url',
              index: '0',
              parameters: [{ type: 'text', text: code }],
            },
          ],
        },
      }),
    },
  );
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.error) {
    throw new Error(`whatsapp failed: ${res.status} ${JSON.stringify(body)}`);
  }
  const id =
    body.messages && body.messages[0] && body.messages[0].id;
  return { provider: 'whatsapp', id: id || '' };
}

const PROVIDERS = {
  whatsapp: sendViaWhatsapp,
};

/**
 * يرسل كود OTP عبر المزوّد الأساسي، وعند فشله يجرّب الاحتياطي (إن ضُبط).
 * يرمي Error لو فشل الجميع — من يستدعيها يحوّلها HttpsError.
 * @returns {{provider: string}} اسم المزوّد الذي نجح فعلياً.
 */
async function sendOtpSms(phone, code) {
  const text = otpMessage(code);
  const primary = (process.env.SMS_PROVIDER_PRIMARY || 'whatsapp').trim();
  const fallback = (process.env.SMS_PROVIDER_FALLBACK || '').trim();

  const order = [primary, fallback].filter((p) => p && PROVIDERS[p]);
  if (order.length === 0) {
    throw new Error(`no valid SMS provider configured (primary="${primary}")`);
  }

  let lastErr;
  for (const name of order) {
    try {
      const result = await PROVIDERS[name](phone, text, code);
      console.log(`[sendOtpSms] ✓ sent via ${name} (id=${result.id || '-'})`);
      return { provider: name };
    } catch (err) {
      lastErr = err;
      console.warn(`[sendOtpSms] ${name} failed:`, err.message);
    }
  }
  throw lastErr;
}

module.exports = { sendOtpSms };

/**
 * طبقة إرسال SMS قابلة للتبديل — بدون أي dependencies (fetch مدمج في Node 20).
 *
 * ⭐ المزوّد الأساسي: textbee (بوابة SIM محلية) — الوحيد الموثوق للسودان.
 * السبب: كل المزوّدين الدوليين (Unimatrix / CheapGlobalSMS / BudgetSMS /
 * Twilio) فشلوا فعلياً في التوصيل للسودان (تقارير تسليم كاذبة بسبب العقوبات
 * والمسارات الرمادية). الحل الوحيد المضمون هو الإرسال من *داخل* السودان عبر
 * شريحة محلية (زين/MTN/سوداني) على هاتف أندرويد يشغّل تطبيق بوابة —
 * فتصل الرسالة on-net (داخل الشبكة) 100% وفوراً وبسعر باقة محلية.
 * البدائل الدولية تبقى في الكود كخطة طوارئ فقط (لن تُستخدم عملياً للسودان).
 *
 * التبديل بين المزوّدين = تغيير SMS_PROVIDER_PRIMARY / SMS_PROVIDER_FALLBACK
 * (env params) بدون أي تعديل كود. مفاتيح كل مزوّد تُقرأ من process.env —
 * تُضبط كـ Secrets في index.js (انظر تعليقات كل مزوّد لأسماء المفاتيح).
 */

/** يبني نص رسالة الكود — لاتيني/GSM-7 (مقطع واحد، أوسع توافق).
 *  ملاحظة: عبر بوابة SIM المحلية يمكن استخدام العربية بأمان (on-net) لكن
 *  نُبقيه لاتينياً للتوحيد مع البدائل الدولية. */
function otpMessage(code) {
  return `Tala LOOK verification code: ${code}`;
}

/** textbee — بوابة SIM محلية عبر هاتف أندرويد بشريحة سودانية.
 *  https://textbee.dev — REST بسيط، مجاني حتى 300/شهر ثم $9.99/شهر لا محدود.
 *  المفاتيح: TEXTBEE_API_KEY + TEXTBEE_DEVICE_ID (secrets).
 *  الأرقام بصيغة E.164 مع + . */
async function sendViaTextbee(phone, text) {
  const apiKey = process.env.TEXTBEE_API_KEY;
  const deviceId = process.env.TEXTBEE_DEVICE_ID;
  if (!apiKey || !deviceId) {
    throw new Error('textbee: TEXTBEE_API_KEY/TEXTBEE_DEVICE_ID not configured');
  }
  const res = await fetch(
    `https://api.textbee.dev/api/v1/gateway/devices/${encodeURIComponent(deviceId)}/send-sms`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey },
      body: JSON.stringify({ recipients: [phone], message: text }),
    },
  );
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`textbee failed: ${res.status} ${JSON.stringify(body)}`);
  }
  return { provider: 'textbee', id: (body.data && body.data._id) || '' };
}

/** CheapGlobalSMS — https://cheapglobalsms.com/api_docs
 *  المفاتيح: CGS_SUB_ACCOUNT + CGS_PASSWORD (secrets).
 *  الأرقام بصيغة دولية بدون + (مثال: 249117777051). */
async function sendViaCheapGlobalSms(phone, text) {
  const subAccount = process.env.CGS_SUB_ACCOUNT;
  const password = process.env.CGS_PASSWORD;
  if (!subAccount || !password) {
    throw new Error('cheapglobalsms: CGS_SUB_ACCOUNT/CGS_PASSWORD not configured');
  }
  const params = new URLSearchParams({
    sub_account: subAccount,
    sub_account_pass: password,
    action: 'send_sms',
    sender_id: process.env.SMS_SENDER_ID || 'TalaLOOK',
    message: text,
    recipients: phone.replace(/^\+/, ''),
  });
  const res = await fetch(`https://cheapglobalsms.com/api_v1/?${params}`, {
    method: 'POST',
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.error || !body.batch_id) {
    throw new Error(`cheapglobalsms failed: ${res.status} ${JSON.stringify(body)}`);
  }
  return { provider: 'cheapglobalsms', id: String(body.batch_id) };
}

/** Unimatrix — https://www.unimtx.com/docs/api/send
 *  المفتاح: UNIMTX_ACCESS_KEY (secret). الأرقام بصيغة E.164 مع +.
 *  ⚠️ النص الحر يرفض بـ SmsTemplateNotExists — يجب استخدام قالب تحقق عام
 *  (pub_verif_en_basic2) مع تمرير الكود في templateData (مجرَّب ويعمل). */
async function sendViaUnimatrix(phone, text, code) {
  const accessKey = process.env.UNIMTX_ACCESS_KEY;
  if (!accessKey) throw new Error('unimatrix: UNIMTX_ACCESS_KEY not configured');
  const res = await fetch(
    `https://api.unimtx.com/?action=sms.message.send&accessKeyId=${encodeURIComponent(accessKey)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: phone,
        templateId: process.env.UNIMTX_TEMPLATE_ID || 'pub_verif_en_basic2',
        templateData: { code },
      }),
    },
  );
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.code !== '0') {
    throw new Error(`unimatrix failed: ${res.status} ${JSON.stringify(body)}`);
  }
  const first =
    body.data && Array.isArray(body.data.messages) && body.data.messages[0];
  return { provider: 'unimatrix', id: (first && first.id) || '' };
}

/** BudgetSMS — https://www.budgetsms.net/sms-http-api/
 *  المفاتيح: BUDGETSMS_USERNAME + BUDGETSMS_USERID + BUDGETSMS_HANDLE (secrets).
 *  الأرقام بصيغة دولية بدون + . الردّ نصّي: "OK ..." أو "ERR ..." */
async function sendViaBudgetSms(phone, text) {
  const username = process.env.BUDGETSMS_USERNAME;
  const userid = process.env.BUDGETSMS_USERID;
  const handle = process.env.BUDGETSMS_HANDLE;
  if (!username || !userid || !handle) {
    throw new Error('budgetsms: BUDGETSMS_* not configured');
  }
  const params = new URLSearchParams({
    username,
    userid,
    handle,
    from: process.env.SMS_SENDER_ID || 'TalaLOOK',
    to: phone.replace(/^\+/, ''),
    msg: text,
  });
  const res = await fetch(`https://api.budgetsms.net/sendsms/?${params}`);
  const body = (await res.text()).trim();
  if (!res.ok || !body.startsWith('OK')) {
    throw new Error(`budgetsms failed: ${res.status} ${body}`);
  }
  return { provider: 'budgetsms', id: body.split(' ')[1] || '' };
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
  textbee: sendViaTextbee,
  cheapglobalsms: sendViaCheapGlobalSms,
  unimatrix: sendViaUnimatrix,
  budgetsms: sendViaBudgetSms,
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

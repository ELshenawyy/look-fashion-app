const functions = require('firebase-functions');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
admin.initializeApp();

// ── OTP عبر واتساب (WhatsApp Cloud API — الحل المعتمد للسودان) ─────────────
// واتساب يعمل عبر الإنترنت فيتجاوز مشكلة توصيل الـ SMS للسودان تماماً.
// Secrets: firebase functions:secrets:set WHATSAPP_ACCESS_TOKEN (وPHONE_NUMBER_ID)
// Config (functions/.env): SMS_PROVIDER_PRIMARY=whatsapp + WHATSAPP_TEMPLATE_NAME
// + WHATSAPP_TEMPLATE_LANG. (البدائل textbee/unimatrix تبقى للطوارئ.)
const crypto = require('crypto');
const { sendOtpSms } = require('./sms_providers');
const WHATSAPP_ACCESS_TOKEN = defineSecret('WHATSAPP_ACCESS_TOKEN');
const WHATSAPP_PHONE_NUMBER_ID = defineSecret('WHATSAPP_PHONE_NUMBER_ID');
// ملاحظة: textbee (بوابة SIM احتياطية) غير مُفعَّل حالياً (لا جهاز مربوط) —
// أُزيلت أسراره من هنا حتى لا تُعطّل النشر. لتفعيله لاحقاً: أعد تعريف
// TEXTBEE_API_KEY/TEXTBEE_DEVICE_ID كـ defineSecret، أضفهما لـ OTP_SECRETS،
// واضبط SMS_PROVIDER_FALLBACK=textbee في functions/.env.
const OTP_SECRETS = [WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID];

const OTP_TTL_MS = 5 * 60 * 1000; // صلاحية الكود: 5 دقائق
const OTP_MAX_ATTEMPTS = 5; // أقصى محاولات إدخال خاطئة قبل إلغاء الكود

/** hash الكود المخزَّن — الرقم داخل الـ hash يمنع نقل كود رقمٍ لرقمٍ آخر. */
function hashOtp(phone, code) {
  return crypto.createHash('sha256').update(`${phone}:${code}`).digest('hex');
}

const CHANNEL_ID = 'high_importance_channel';

/**
 * Callable — يتحقق هل الرقم مسجَّل في التطبيق قبل إرسال الـ OTP.
 *
 * لماذا Cloud Function وليس استعلام من العميل؟ قواعد Firestore لا تسمح
 * لمستخدم غير مسجَّل دخول بقراءة/استعلام مجموعة `users` (لتجنّب تسريب أرقام
 * المستخدمين). هذه الدالة تعمل بصلاحيات الأدمن server-side فتتجاوز القواعد
 * بأمان وتُرجع فقط boolean دون كشف أي بيانات.
 *
 * ⚠️ المعيار هو وجود مستند `users` بهذا الرقم (وليس مجرد حساب Firebase Auth)،
 * لأن تسجيل الدخول بالهاتف قد يُنشئ حساب Auth وهمياً لرقم لم يُكمل التسجيل.
 */
exports.isPhoneRegistered = functions.https.onCall(async (data) => {
  const phone = String((data && data.phone) || '').trim();
  if (!phone.startsWith('+')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'phone must be in E.164 format (e.g. +201200507628)',
    );
  }
  try {
    const snap = await admin.firestore()
      .collection('users')
      .where('phone', '==', phone)
      .limit(1)
      .get();
    return { registered: !snap.empty };
  } catch (err) {
    console.error('[isPhoneRegistered] error:', err);
    throw new functions.https.HttpsError('internal', 'lookup failed');
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// OTP عبر SMS مباشر — بديل Firebase Phone Auth (لا يدعم السودان +249)
// نولّد الكود بأنفسنا (hash في Firestore بصلاحية 5 دقائق) ونرسله عبر مزوّد
// SMS رخيص بمسارات سودانية (sms_providers.js — قابل للتبديل بالإعدادات).
// الدخول النهائي عبر Custom Token → تُحفظ الـ UIDs وبنية Firestore كما هي.
// ═══════════════════════════════════════════════════════════════════════════

/** أكواد أخطاء بصيغة يفهمها _mapAuthError في تطبيق Flutter (تُوضع في message). */
const AUTH_CODES = {
  phoneAlreadyRegistered: 'phone-already-registered',
  userNotRegistered: 'user-not-registered',
  invalidCode: 'invalid-verification-code',
  sessionExpired: 'session-expired',
  tooManyRequests: 'too-many-requests',
  invalidPhone: 'invalid-phone-number',
  userBanned: 'user-banned',
};

const VALID_INTENTS = ['signup', 'login', 'update'];

function assertValidPhone(phone) {
  // E.164: + ثم 8-15 رقماً — نفس معيار isPhoneRegistered أعلاه.
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) {
    throw new HttpsError('invalid-argument', AUTH_CODES.invalidPhone);
  }
}

/** استعلام مستند users بالرقم — نفس معيار isPhoneRegistered (مستند Firestore
 *  وليس حساب Auth، لأن حسابات Auth الوهمية من النظام القديم قد تكون موجودة). */
async function findUserDocByPhone(phone) {
  const snap = await admin.firestore()
    .collection('users')
    .where('phone', '==', phone)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0];
}

const OTP_MAX_PER_PHONE_PER_HOUR = 3;
/** سقف يومي إجمالي لكل الأرقام — قاطع دائرة يحمي رصيد الرسائل من الاستنزاف
 *  لو حاول مهاجم اللف على أرقام كثيرة (حد الرقم الواحد وحده لا يمنع ذلك).
 *  200 رسالة/يوم ≈ $30 كحد أقصى للخسارة اليومية. يُعدَّل عبر متغيّر البيئة
 *  OTP_MAX_PER_DAY دون تعديل كود. */
const OTP_MAX_PER_DAY = Number(process.env.OTP_MAX_PER_DAY || 200);

/** كل مستندات الـ OTP تحمل expireAt ليحذفها Firestore TTL تلقائياً
 *  (سياسة TTL تُفعَّل مرة واحدة من الكونسول — انظر README النشر). */
function expireAtMs(ms) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + ms);
}

/** Rate limiting خادمي على مستويين — يحمي فاتورة الرسائل من الإساءة:
 *  1) حد الرقم الواحد: 3 إرسالات/ساعة.
 *  2) حد يومي إجمالي لكل الأرقام (قاطع دائرة ضد اللف على أرقام كثيرة). */
async function enforceOtpRateLimit(phone) {
  const db = admin.firestore();
  const phoneRef = db.collection('otpRequests').doc(phone);
  // مستند عدّاد يومي واحد — مفتاحه التاريخ (UTC) ويُحذف تلقائياً بعد يومين.
  const dayKey = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const dailyRef = db.collection('otpDailyQuota').doc(dayKey);

  await db.runTransaction(async (tx) => {
    // كل القراءات قبل أي كتابة (شرط معاملات Firestore).
    const [phoneDoc, dailyDoc] = await Promise.all([
      tx.get(phoneRef),
      tx.get(dailyRef),
    ]);

    const now = Date.now();
    const hourAgo = now - 60 * 60 * 1000;
    const recent = ((phoneDoc.data() && phoneDoc.data().timestamps) || [])
      .filter((t) => typeof t === 'number' && t > hourAgo);
    if (recent.length >= OTP_MAX_PER_PHONE_PER_HOUR) {
      throw new HttpsError('resource-exhausted', AUTH_CODES.tooManyRequests);
    }

    const sentToday = (dailyDoc.data() && dailyDoc.data().count) || 0;
    if (sentToday >= OTP_MAX_PER_DAY) {
      console.error(
        `[otp] ⛔ daily cap reached (${sentToday}/${OTP_MAX_PER_DAY}) — ` +
        'possible abuse or unusually high traffic',
      );
      throw new HttpsError('resource-exhausted', AUTH_CODES.tooManyRequests);
    }

    recent.push(now);
    tx.set(phoneRef, {
      timestamps: recent,
      updatedAt: FieldValue.serverTimestamp(),
      // ساعتان تكفيان لأن الحساب يعتمد على آخر ساعة فقط.
      expireAt: expireAtMs(2 * 60 * 60 * 1000),
    });
    tx.set(dailyRef, {
      count: FieldValue.increment(1),
      expireAt: expireAtMs(2 * 24 * 60 * 60 * 1000),
    }, { merge: true });
  });
}

/**
 * Callable — يولّد كود تحقق ويرسله SMS عبر مزوّد الرسائل المُعدّ.
 * data: { phone: '+249...', intent: 'signup' | 'login' | 'update' }
 * يرجع: { status: 'pending', channel: 'sms' }
 *
 * فحص التسجيل يتم هنا (قبل دفع تكلفة الرسالة) *وأيضاً* في verifyPhoneOtp
 * (server-side enforcement يغلق ثغرة تداخل الحسابات وTOCTOU نهائياً).
 */
exports.sendPhoneOtp = onCall(
  { secrets: OTP_SECRETS },
  async (request) => {
    const phone = String((request.data && request.data.phone) || '').trim();
    const intent = String((request.data && request.data.intent) || 'login');
    assertValidPhone(phone);
    if (!VALID_INTENTS.includes(intent)) {
      throw new HttpsError('invalid-argument', 'invalid-intent');
    }
    // تعديل الرقم يتطلب مستخدماً مسجَّل دخوله.
    if (intent === 'update' && !request.auth) {
      throw new HttpsError('unauthenticated', 'not-authenticated');
    }

    await enforceOtpRateLimit(phone);

    // ── فحص التسجيل حسب النية ──────────────────────────────────────────
    const userDoc = await findUserDocByPhone(phone);
    if (intent === 'signup' && userDoc) {
      throw new HttpsError('already-exists', AUTH_CODES.phoneAlreadyRegistered);
    }
    if (intent === 'login' && !userDoc) {
      throw new HttpsError('not-found', AUTH_CODES.userNotRegistered);
    }
    if (intent === 'update' && userDoc && userDoc.id !== request.auth.uid) {
      // الرقم الجديد مربوط بحساب شخص آخر
      throw new HttpsError('already-exists', AUTH_CODES.phoneAlreadyRegistered);
    }

    // ── توليد الكود وتخزين الـ hash ثم الإرسال ─────────────────────────
    // نخزّن قبل الإرسال حتى لا يوجد كود مُرسَل بلا سجل يتحقق منه.
    const code = crypto.randomInt(100000, 1000000).toString();
    const otpRef = admin.firestore().collection('otpCodes').doc(phone);
    await otpRef.set({
      codeHash: hashOtp(phone, code),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS),
      attempts: 0,
      intent,
      createdAt: FieldValue.serverTimestamp(),
      // يحذفه Firestore TTL تلقائياً لو هُجر الكود ولم يُستخدم (بعد مهلة
      // أطول قليلاً من صلاحيته حتى لا يُحذف كود صالح أثناء إدخاله).
      expireAt: expireAtMs(OTP_TTL_MS + 10 * 60 * 1000),
    });

    let sendResult;
    try {
      sendResult = await sendOtpSms(phone, code);
    } catch (err) {
      console.error('[sendPhoneOtp] all providers failed:', err.message);
      // نظّف السجل حتى لا يبقى كود «معلَّق» لم يصل لصاحبه.
      await otpRef.delete().catch(() => {});
      throw new HttpsError('internal', 'otp-send-failed');
    }

    // القناة الفعلية اللي نجح بيها الإرسال (واتساب أو أي مزوّد SMS احتياطي)
    // — لا نُصلّبها 'sms' دائماً حتى تعرض الواجهة الرسالة الصحيحة للمستخدم.
    const channel = sendResult.provider === 'whatsapp' ? 'whatsapp' : 'sms';
    return { status: 'pending', channel };
  },
);

/**
 * Callable — يتحقق من الكود ويُصدر Custom Token للدخول إلى Firebase.
 * data: { phone, code, intent, displayName? }
 * signup/login → { customToken }، update → { ok: true }
 *
 * ⚠️ Security: هنا الإنفاذ الفعلي لقاعدة "رقم مسجَّل لا يُسجَّل من جديد" —
 * server-side بصلاحيات Admin، لا يمكن تخطّيه من عميل معدَّل، ويغلق نافذة
 * الـ TOCTOU (الفحص يتم لحظة إصدار الجلسة وليس فقط لحظة الإرسال).
 */
exports.verifyPhoneOtp = onCall(
  { secrets: OTP_SECRETS },
  async (request) => {
    const phone = String((request.data && request.data.phone) || '').trim();
    const code = String((request.data && request.data.code) || '').trim();
    const intent = String((request.data && request.data.intent) || 'login');
    const displayName =
      String((request.data && request.data.displayName) || '').trim();
    assertValidPhone(phone);
    if (!/^\d{4,10}$/.test(code)) {
      throw new HttpsError('invalid-argument', AUTH_CODES.invalidCode);
    }
    if (!VALID_INTENTS.includes(intent)) {
      throw new HttpsError('invalid-argument', 'invalid-intent');
    }
    if (intent === 'update' && !request.auth) {
      throw new HttpsError('unauthenticated', 'not-authenticated');
    }

    // ── 1) تحقق الكود من سجلنا (transaction: انتهاء صلاحية + محاولات) ──
    const db = admin.firestore();
    const otpRef = db.collection('otpCodes').doc(phone);
    const checkResult = await db.runTransaction(async (tx) => {
      const doc = await tx.get(otpRef);
      if (!doc.exists) return 'expired';
      const d = doc.data();
      if (!d.expiresAt || d.expiresAt.toMillis() < Date.now()) {
        tx.delete(otpRef);
        return 'expired';
      }
      if ((d.attempts || 0) >= OTP_MAX_ATTEMPTS) {
        tx.delete(otpRef);
        return 'too-many';
      }
      if (d.codeHash !== hashOtp(phone, code)) {
        // محاولة خاطئة تُحتسب وتُحفظ حتى لو أُعيد الطلب فوراً.
        tx.update(otpRef, { attempts: FieldValue.increment(1) });
        return 'wrong';
      }
      // نجاح — يُستهلك الكود فوراً (لا يُعاد استخدامه أبداً).
      tx.delete(otpRef);
      return 'ok';
    });

    if (checkResult === 'expired') {
      throw new HttpsError('failed-precondition', AUTH_CODES.sessionExpired);
    }
    if (checkResult === 'too-many') {
      throw new HttpsError('resource-exhausted', AUTH_CODES.tooManyRequests);
    }
    if (checkResult === 'wrong') {
      throw new HttpsError('invalid-argument', AUTH_CODES.invalidCode);
    }

    // ── 2) تنفيذ النية بصلاحيات Admin ─────────────────────────────────
    if (intent === 'update') {
      const uid = request.auth.uid;
      const existing = await findUserDocByPhone(phone);
      if (existing && existing.id !== uid) {
        throw new HttpsError('already-exists', AUTH_CODES.phoneAlreadyRegistered);
      }
      try {
        await admin.auth().updateUser(uid, { phoneNumber: phone });
      } catch (err) {
        if (err.code === 'auth/phone-number-already-exists') {
          throw new HttpsError('already-exists', AUTH_CODES.phoneAlreadyRegistered);
        }
        throw new HttpsError('internal', 'phone-update-failed');
      }
      await db.collection('users').doc(uid).update({ phone });
      return { ok: true };
    }

    const userDoc = await findUserDocByPhone(phone);

    if (intent === 'signup') {
      if (userDoc) {
        // الرقم مسجَّل بالفعل — نرفض (لا دخول صامت لحساب شخص آخر).
        throw new HttpsError('already-exists', AUTH_CODES.phoneAlreadyRegistered);
      }
      // أعد استخدام حساب Auth الوهمي إن وُجد (من النظام القديم) وإلا أنشئ جديداً.
      let uid;
      try {
        uid = (await admin.auth().getUserByPhoneNumber(phone)).uid;
      } catch (err) {
        if (err.code !== 'auth/user-not-found') {
          console.error('[verifyPhoneOtp] getUserByPhoneNumber:', err);
          throw new HttpsError('internal', 'signup-failed');
        }
        const created = await admin.auth().createUser({
          phoneNumber: phone,
          displayName: displayName || undefined,
        });
        uid = created.uid;
      }
      await db.collection('users').doc(uid).set({
        uid,
        name: displayName,
        phone,
        role: 'user',
        createdAt: FieldValue.serverTimestamp(),
      });
      const customToken = await admin.auth().createCustomToken(uid);
      return { customToken };
    }

    // intent === 'login'
    if (!userDoc) {
      throw new HttpsError('not-found', AUTH_CODES.userNotRegistered);
    }
    if (userDoc.data().banned === true) {
      throw new HttpsError('permission-denied', AUTH_CODES.userBanned);
    }
    const customToken = await admin.auth().createCustomToken(userDoc.id);
    return { customToken };
  },
);

/**
 * Triggered whenever a document is created in the `notifications` collection.
 * Reads forUserId / forRole to determine recipients, fetches their FCM tokens
 * from Firestore, and sends the push via the Admin SDK (server-side — no private
 * key in the Flutter app).
 */
exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data) return null;

    const title = data.title || '';
    const body  = data.body  || '';
    const extraData = {};
    if (data.orderId) extraData.orderId = String(data.orderId);
    if (data.type)    extraData.type    = String(data.type);

    const androidConfig = {
      priority: 'high',
      notification: { channel_id: CHANNEL_ID, sound: 'default' },
    };

    try {
      if (data.forUserId) {
        const userDoc = await admin.firestore()
          .collection('users').doc(data.forUserId).get();
        const token = userDoc.data() && userDoc.data().fcmToken;
        if (!token) return null;

        await admin.messaging().send({
          token,
          notification: { title, body },
          data: extraData,
          android: androidConfig,
        });

      } else if (data.forRole === 'admin') {
        const adminsSnap = await admin.firestore()
          .collection('users')
          .where('role', 'in', ['admin', 'superAdmin'])
          .get();

        const tokens = adminsSnap.docs
          .map(d => d.data().fcmToken)
          .filter(t => typeof t === 'string' && t.length > 0);

        if (tokens.length === 0) return null;

        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: extraData,
          android: androidConfig,
        });
      }

      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('[sendNotification] error:', err);
    }

    return null;
  });

/**
 * Triggered whenever a new order is created in the `orders` collection.
 *
 * For each ordered product it (server-side, via the Admin SDK, which bypasses
 * Firestore security rules):
 *   - increments `salesCount` by the quantity ordered  → powers "best sellers"
 *   - decrements `stockQuantity` by the quantity ordered → keeps stock accurate
 *
 * The client app must NOT update product docs itself (security rules only allow
 * admins to write to `products`), so this is the single source of truth for both
 * counters.
 *
 * Idempotent: marks the order with `inventoryProcessed: true` inside the same
 * transaction, so a function retry never double-counts.
 */
exports.updateInventoryOnOrder = onDocumentCreated('orders/{orderId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const order = snap.data();
  if (!order || !Array.isArray(order.items) || order.items.length === 0) return;

  // Aggregate quantity per product (same product can appear twice with a
  // different size/color and must be summed).
  const qtyByProduct = {};
  for (const item of order.items) {
    const pid = item && item.productId;
    const qty = item && Number(item.quantity);
    if (!pid || !Number.isFinite(qty) || qty <= 0) continue;
    qtyByProduct[pid] = (qtyByProduct[pid] || 0) + qty;
  }
  const productIds = Object.keys(qtyByProduct);
  if (productIds.length === 0) return;

  const db = admin.firestore();
  const orderRef = snap.ref;

  try {
    await db.runTransaction(async (tx) => {
      // Idempotency guard — bail out if a previous run already processed this order.
      const freshOrder = await tx.get(orderRef);
      if (!freshOrder.exists || freshOrder.get('inventoryProcessed') === true) {
        return;
      }

      const productRefs = productIds.map((id) => db.collection('products').doc(id));
      const productSnaps = await Promise.all(productRefs.map((ref) => tx.get(ref)));

      productSnaps.forEach((pSnap, i) => {
        if (!pSnap.exists) return; // product was deleted — skip, don't resurrect it
        const qty = qtyByProduct[productIds[i]];
        tx.update(productRefs[i], {
          salesCount: FieldValue.increment(qty),
          stockQuantity: FieldValue.increment(-qty),
        });
      });

      tx.update(orderRef, { inventoryProcessed: true });
    });
  } catch (err) {
    console.error('[updateInventoryOnOrder] error:', err);
  }
});

/**
 * Triggered when an order is UPDATED and its status transitions to "cancelled".
 *
 * Reverses the sales count that `updateInventoryOnOrder` added at creation, so
 * cancelled orders no longer inflate the best-seller ranking. It decrements
 * `salesCount` on each product by the quantity that was ordered.
 *
 * Stock restoration is intentionally NOT done here — the admin cancel flow in
 * order_remote_datasource.dart already increments `stockQuantity` back (cancels
 * are admin-only, which Firestore rules permit). Doing it here too would restore
 * stock twice.
 *
 * Idempotent: marks the order `salesCountRestored: true` inside the transaction,
 * and only acts when the order was actually counted (`inventoryProcessed: true`),
 * so it never runs twice or decrements sales that were never added.
 */
exports.decrementSalesOnCancel = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!before || !after) return;

  // Only react to the transition INTO cancelled.
  if (before.status === 'cancelled' || after.status !== 'cancelled') return;
  // Only reverse a count that was actually applied, and only once.
  if (after.inventoryProcessed !== true) return;
  if (after.salesCountRestored === true) return;

  const items = Array.isArray(after.items) ? after.items : [];
  if (items.length === 0) return;

  // Aggregate quantity per product (same product can appear with different size/color).
  const qtyByProduct = {};
  for (const item of items) {
    const pid = item && item.productId;
    const qty = item && Number(item.quantity);
    if (!pid || !Number.isFinite(qty) || qty <= 0) continue;
    qtyByProduct[pid] = (qtyByProduct[pid] || 0) + qty;
  }
  const productIds = Object.keys(qtyByProduct);
  if (productIds.length === 0) return;

  const db = admin.firestore();
  const orderRef = event.data.after.ref;

  try {
    await db.runTransaction(async (tx) => {
      // Re-check guards on fresh data inside the transaction (retry/race safety).
      const freshOrder = await tx.get(orderRef);
      if (!freshOrder.exists) return;
      if (freshOrder.get('status') !== 'cancelled') return;
      if (freshOrder.get('inventoryProcessed') !== true) return;
      if (freshOrder.get('salesCountRestored') === true) return;

      const productRefs = productIds.map((id) => db.collection('products').doc(id));
      const productSnaps = await Promise.all(productRefs.map((ref) => tx.get(ref)));

      productSnaps.forEach((pSnap, i) => {
        if (!pSnap.exists) return; // product was deleted — skip
        const qty = qtyByProduct[productIds[i]];
        tx.update(productRefs[i], {
          salesCount: FieldValue.increment(-qty),
        });
      });

      tx.update(orderRef, { salesCountRestored: true });
    });
  } catch (err) {
    console.error('[decrementSalesOnCancel] error:', err);
  }
});

const functions = require('firebase-functions');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
admin.initializeApp();

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

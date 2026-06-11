const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const CHANNEL_ID = 'high_importance_channel';

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

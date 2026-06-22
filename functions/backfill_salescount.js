/**
 * One-time backfill: set `salesCount: 0` on every product that doesn't have it.
 *
 * Why: the "best sellers" tab queries `orderBy('salesCount', descending: true)`,
 * and Firestore EXCLUDES documents that are missing the ordered field. Without
 * this backfill, products that never sold would simply never appear in the tab.
 *
 * How to run (from the `functions/` folder):
 *   1. Firebase Console → Project Settings → Service accounts →
 *      "Generate new private key" → save the JSON somewhere safe.
 *   2. PowerShell:
 *        $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccount.json"
 *        node backfill_salescount.js
 *      (bash:  export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
 *              node backfill_salescount.js )
 *
 * Safe to run more than once — it only touches products missing the field.
 */
const admin = require('firebase-admin');

admin.initializeApp(); // uses GOOGLE_APPLICATION_CREDENTIALS
const db = admin.firestore();

(async () => {
  const snap = await db.collection('products').get();
  console.log(`Scanning ${snap.size} products...`);

  let batch = db.batch();
  let pending = 0;
  let updated = 0;

  for (const doc of snap.docs) {
    if (doc.get('salesCount') === undefined) {
      batch.update(doc.ref, { salesCount: 0 });
      pending++;
      updated++;
      // Firestore batches are capped at 500 writes; commit well under the limit.
      if (pending >= 450) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
  }

  if (pending > 0) await batch.commit();

  console.log(`Done. Set salesCount: 0 on ${updated} product(s).`);
  process.exit(0);
})().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});

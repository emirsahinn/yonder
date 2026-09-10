// One-time backfill for rooms/{code}/participants/{uid} documents.
//
// AccountDeletionService now finds a user's participant records via
// `whereField("uid", isEqualTo: uid)` instead of matching the document ID.
// Every participant document has always been created with its document ID
// equal to the joining user's uid, so `uid: doc.id` is always a correct value
// to backfill for any document that predates the new field.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run backfill
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run backfill -- --apply
//
// Without --apply this only reports how many documents would be touched
// (dry run). Pass --apply to actually write. Safe to re-run: it only ever
// touches documents that are still missing the `uid` field.

const admin = require("firebase-admin");

const PROJECT_ID = "yonder-74bbb";
const PAGE_SIZE = 500;
const BATCH_LIMIT = 400;

const apply = process.argv.includes("--apply");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
});

const db = admin.firestore();

async function main() {
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${apply ? "APPLY (will write)" : "DRY RUN (no writes)"}`);
  console.log("");

  let lastDoc = null;
  let scanned = 0;
  let missing = 0;
  let written = 0;
  let pendingWrites = [];

  while (true) {
    let query = db.collectionGroup("participants").orderBy("__name__").limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      scanned += 1;
      const data = doc.data();
      if (typeof data.uid !== "string" || data.uid.length === 0) {
        missing += 1;
        const expectedUid = doc.id;
        console.log(`  missing uid: ${doc.ref.path} -> would set uid="${expectedUid}"`);
        if (apply) {
          pendingWrites.push({ ref: doc.ref, uid: expectedUid });
        }
      }
    }

    if (apply && pendingWrites.length > 0) {
      written += await flush(pendingWrites);
      pendingWrites = [];
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.docs.length < PAGE_SIZE) break;
  }

  if (apply && pendingWrites.length > 0) {
    written += await flush(pendingWrites);
  }

  console.log("");
  console.log(`Scanned:  ${scanned}`);
  console.log(`Missing:  ${missing}`);
  if (apply) {
    console.log(`Written:  ${written}`);
  } else {
    console.log("Nothing written (dry run). Re-run with --apply to write.");
  }
}

async function flush(pending) {
  let count = 0;
  for (let i = 0; i < pending.length; i += BATCH_LIMIT) {
    const chunk = pending.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const { ref, uid } of chunk) {
      batch.set(ref, { uid }, { merge: true });
    }
    await batch.commit();
    count += chunk.length;
  }
  return count;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Backfill failed:", error);
    process.exit(1);
  });

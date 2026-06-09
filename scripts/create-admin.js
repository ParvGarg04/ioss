/**
 * Promote an existing Firebase Auth user to admin role.
 *
 * Usage:
 *   1. Create a user account via the iOS app or Firebase Console → Authentication
 *   2. Download service account JSON (Firebase Console → Project Settings → Service accounts → Generate new private key)
 *   3. Run from the scripts/ folder:
 *
 *      node create-admin.js user@email.com C:\path\to\serviceAccountKey.json
 *
 *   Or set GOOGLE_APPLICATION_CREDENTIALS first, then:
 *      node create-admin.js user@email.com
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const email = process.argv[2];
const keyPath = process.argv[3] || process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!email) {
  console.error('Usage: node create-admin.js <email> [path-to-serviceAccountKey.json]');
  console.error('');
  console.error('Example (Windows):');
  console.error('  cd ..\\scripts');
  console.error('  npm install');
  console.error('  node create-admin.js you@email.com C:\\Downloads\\serviceAccountKey.json');
  process.exit(1);
}

if (!keyPath) {
  console.error('Missing Firebase service account key.');
  console.error('');
  console.error('Download it from: Firebase Console → Project Settings → Service accounts → Generate new private key');
  console.error('');
  console.error('Then run:');
  console.error(`  node create-admin.js ${email} C:\\path\\to\\serviceAccountKey.json`);
  process.exit(1);
}

const resolvedKey = path.resolve(keyPath);
if (!fs.existsSync(resolvedKey)) {
  console.error(`Service account file not found: ${resolvedKey}`);
  process.exit(1);
}

const serviceAccount = require(resolvedKey);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();

async function main() {
  const user = await auth.getUserByEmail(email);
  await db.collection('users').doc(user.uid).set(
    {
      uid: user.uid,
      name: user.displayName || 'Admin',
      email: user.email,
      role: 'admin',
      streak: 0,
      points: 0,
      notificationsEnabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`✅ User ${email} (${user.uid}) promoted to admin.`);
  console.log('   You can now sign in at the admin dashboard.');
}

main().catch((err) => {
  if (err.code === 'auth/user-not-found') {
    console.error(`❌ No Firebase Auth account found for ${email}.`);
    console.error('   Create the account first in the iOS app or Firebase Console → Authentication.');
  } else {
    console.error('❌ Error:', err.message || err);
  }
  process.exit(1);
});

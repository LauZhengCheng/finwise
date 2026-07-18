// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : firebase.js
// Description   : Firebase Admin SDK initialisation using modular API.
//                 Local dev: reads service account JSON from file path.
//                 Production: reads JSON content from env var (Secret Manager).
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

if (!getApps().length) {
  let credential;

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    credential = cert(serviceAccount);
  } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    const serviceAccount = require(
      require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
    );
    credential = cert(serviceAccount);
  } else {
    throw new Error('No Firebase credentials configured.');
  }

  initializeApp({ credential });
}

module.exports = { getMessaging };

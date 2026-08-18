'use strict';

const admin = require('firebase-admin');

const DEFAULT_TOPIC = 'stock_updates';

let initialized = false;

/**
 * Initializes the firebase-admin SDK once, lazily, using the service account
 * JSON passed via the FIREBASE_SERVICE_ACCOUNT env var.
 *
 * @param {string} [credentialsJson] service account JSON string
 * @returns {boolean} true when the SDK is initialized and ready to send
 */
function ensureInitialized(credentialsJson) {
  if (initialized) return true;
  if (!credentialsJson) return false;
  try {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(credentialsJson)),
    });
    initialized = true;
    return true;
  } catch (err) {
    console.error(`notifier: failed to initialize firebase-admin: ${err.message}`);
    return false;
  }
}

/**
 * Builds the FCM message payload for a stock change.
 *
 * @param {Array<{name: string, imageUrl: string|null}>} fruits current stock
 * @param {string} topic FCM topic name
 * @returns {object} message ready for admin.messaging().send()
 */
function buildMessage(fruits, topic = DEFAULT_TOPIC) {
  const names = fruits.map((f) => f.name);
  const firstImage = fruits.find((f) => f.imageUrl);

  return {
    topic,
    notification: {
      title: 'Stock Updated!',
      body: `New stock: ${names.join(', ')}`,
    },
    data: {
      type: 'stock_update',
      fruits: names.join(','),
      imageUrls: JSON.stringify(
        Object.fromEntries(fruits.map((f) => [f.name, f.imageUrl || '']))
      ),
    },
    android: {
      priority: 'high',
      notification: firstImage ? { image: firstImage.imageUrl } : undefined,
    },
  };
}

/**
 * Sends a stock-change notification to the FCM topic.
 *
 * @param {object} params
 * @param {string[]} params.fruits new stock fruit names
 * @param {string} [params.topic] FCM topic (default stock_updates)
 * @param {string} [params.credentialsJson] FIREBASE_SERVICE_ACCOUNT value
 * @param {object} [params.resolver] optional createImageResolver instance used
 *   to attach image URLs to the payload
 * @returns {Promise<{skipped: boolean}>}
 */
async function notifyStockChange({ fruits, topic, credentialsJson, resolver }) {
  const items = resolver
    ? await resolver.resolveFruits(fruits)
    : fruits.map((name) => ({ name, imageUrl: null }));

  if (!ensureInitialized(credentialsJson)) {
    console.warn('notifier: FIREBASE_SERVICE_ACCOUNT not set, skipping send');
    return { skipped: true };
  }

  const message = buildMessage(items, topic);
  await admin.messaging().send(message);
  return { skipped: false };
}

/**
 * Test-only hook: resets the initialized flag.
 */
function __resetForTest() {
  initialized = false;
}

module.exports = { notifyStockChange, buildMessage, DEFAULT_TOPIC, __resetForTest };

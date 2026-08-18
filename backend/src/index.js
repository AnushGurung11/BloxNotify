'use strict';

require('dotenv').config();

const fs = require('fs');
const axios = require('axios');
const { createApp, DEFAULT_STOCK_FILE } = require('./app');
const { createImageResolver } = require('./fruitImages');
const { startPolling } = require('./poller');
const { DEFAULT_TOPIC } = require('./notifier');

const PORT = Number(process.env.PORT) || 3000;
const stockFile = process.env.STOCK_FILE || DEFAULT_STOCK_FILE;
const topic = process.env.FCM_TOPIC || DEFAULT_TOPIC;
const pollIntervalMs = Number(process.env.POLL_INTERVAL_MS) || undefined;

// Credentials can be passed inline (FIREBASE_SERVICE_ACCOUNT, a JSON string)
// or as a path to the JSON file (FIREBASE_SERVICE_ACCOUNT_FILE).
let credentialsJson = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!credentialsJson && process.env.FIREBASE_SERVICE_ACCOUNT_FILE) {
  try {
    credentialsJson = fs.readFileSync(process.env.FIREBASE_SERVICE_ACCOUNT_FILE, 'utf8');
  } catch (err) {
    console.error(`Could not read FIREBASE_SERVICE_ACCOUNT_FILE: ${err.message}`);
  }
}

const imageResolver = createImageResolver({ axios });

const app = createApp({ stockFile, imageResolver });

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Blox Notify backend listening on :${PORT}`);

  if (!credentialsJson) {
    console.warn('FIREBASE_SERVICE_ACCOUNT not set — notifications will be skipped until it is');
  }

  console.log(`Polling started (interval: ${pollIntervalMs || 'default 90000ms'}, topic: ${topic})`);
  startPolling({
    axios,
    stockFile,
    credentialsJson,
    topic,
    imageResolver,
    pollIntervalMs,
  });
});

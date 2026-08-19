'use strict';

const cron = require('node-cron');
const fruitybloxClient = require('./fruitybloxClient');
const stockStore = require('./stockStore');
const { notifyStockChange } = require('./notifier');

const DEFAULT_INTERVAL_MS = 90 * 1000; // every 90 seconds
const MAX_HISTORY = 50; // previous stock snapshots kept in the state file

/**
 * Converts a poll interval in milliseconds to a node-cron expression with
 * second granularity.
 *
 * @param {number} intervalMs
 * @returns {string} cron expression
 */
function intervalToCron(intervalMs) {
  const seconds = Math.max(1, Math.floor(intervalMs / 1000));
  return `*/${seconds} * * * * *`;
}

/**
 * Runs a single poll cycle: fetch FruityBlox -> diff normal + mirage ->
 * store -> notify each dealer that changed.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance (injectable for tests)
 * @param {string} [deps.stockFile] path to the state file
 * @param {string} [deps.credentialsJson] FIREBASE_SERVICE_ACCOUNT value
 * @param {string} [deps.topic] FCM topic
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {object} [deps.log] logger (defaults to console)
 * @param {Date} [deps.now] reference time (tests)
 * @returns {Promise<{changed: {normal: boolean, mirage: boolean}, normal: string[], mirage: string[], record: object|null}>}
 */
async function checkStockOnce(deps) {
  const log = deps.log || console;
  const stock = await fruitybloxClient.fetchStockPage({
    axios: deps.axios,
    url: deps.fruitybloxUrl,
  });

  const normalFruits = fruitybloxClient.itemNames(stock.normal);
  const mirageFruits = fruitybloxClient.itemNames(stock.mirage);

  // A completely empty parse means the scraper or the site failed — never
  // treat that as a change.
  if (normalFruits.length === 0 && mirageFruits.length === 0) {
    throw new Error('poller: parsed an empty stock, refusing to treat as a change');
  }

  const previous = stockStore.readStock(deps.stockFile);
  const normalChanged = JSON.stringify(previous.normal.fruits) !== JSON.stringify(normalFruits);
  const mirageChanged = JSON.stringify(previous.mirage.fruits) !== JSON.stringify(mirageFruits);

  if (!normalChanged && !mirageChanged) {
    log.info?.(`poller: stock unchanged (normal: ${normalFruits.join(', ')})`);
    return { changed: { normal: false, mirage: false }, normal: normalFruits, mirage: mirageFruits, record: null };
  }

  log.info(
    `poller: normal ${previous.normal.fruits.join(', ') || '(none)'} -> ${normalFruits.join(', ')}` +
    (mirageChanged
      ? ` | mirage ${previous.mirage.fruits.join(', ') || '(none)'} -> ${mirageFruits.join(', ')}`
      : ''),
  );

  // The previous snapshot moves into the history, newest first, capped.
  const historyEntry = (previous.normal.fruits.length > 0 || previous.mirage.fruits.length > 0)
    ? {
        fruits: previous.normal.fruits,
        mirageFruits: previous.mirage.fruits,
        updatedAt: previous.normal.updatedAt || previous.mirage.updatedAt,
      }
    : null;
  const history = [historyEntry, ...(previous.history || [])]
    .filter(Boolean)
    .slice(0, MAX_HISTORY);
  const record = stockStore.writeStock(
    { normal: { fruits: normalFruits }, mirage: { fruits: mirageFruits }, history },
    deps.stockFile,
  );

  // A fresh file after (re)start is just a seed — there is no previous state
  // to compare against, so no notification is sent for that dealer.
  if (normalChanged && previous.normal.fruits.length > 0) {
    await notifyStockChange({
      dealer: 'normal',
      fruits: normalFruits,
      topic: deps.topic,
      credentialsJson: deps.credentialsJson,
      resolver: deps.imageResolver,
    });
  }
  if (mirageChanged && previous.mirage.fruits.length > 0) {
    await notifyStockChange({
      dealer: 'mirage',
      fruits: mirageFruits,
      topic: deps.topic,
      credentialsJson: deps.credentialsJson,
      resolver: deps.imageResolver,
    });
  }

  return { changed: { normal: normalChanged, mirage: mirageChanged }, normal: normalFruits, mirage: mirageFruits, record };
}

/**
 * Starts the periodic polling loop via node-cron.
 *
 * @param {object} deps same as checkStockOnce, plus:
 * @param {number} [deps.pollIntervalMs] poll interval in ms
 * @returns {cron.ScheduledTask} the scheduled task
 */
function startPolling(deps) {
  const intervalMs = deps.pollIntervalMs || DEFAULT_INTERVAL_MS;
  const expression = deps.cronExpression || intervalToCron(intervalMs);
  const task = cron.schedule(expression, () => {
    checkStockOnce(deps).catch((err) => {
      (deps.log || console).error(`poller: cycle failed: ${err.message}`);
    });
  });
  return task;
}

module.exports = { startPolling, checkStockOnce, intervalToCron, DEFAULT_INTERVAL_MS, MAX_HISTORY };
'use strict';

const cron = require('node-cron');
const wikiClient = require('./wikiClient');
const stockParser = require('./stockParser');
const stockStore = require('./stockStore');
const { notifyStockChange } = require('./notifier');

const DEFAULT_INTERVAL_MS = 90 * 1000; // every 90 seconds

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
 * Runs a single poll cycle: fetch wikitext -> parse -> diff -> store -> notify.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance (injectable for tests)
 * @param {string} [deps.stockFile] path to the state file
 * @param {string} [deps.credentialsJson] FIREBASE_SERVICE_ACCOUNT value
 * @param {string} [deps.topic] FCM topic
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {object} [deps.log] logger (defaults to console)
 * @returns {Promise<{changed: boolean, fruits: string[], record: object|null}>}
 */
async function checkStockOnce(deps) {
  const log = deps.log || console;
  const wikitext = await wikiClient.fetchStockWikitext({
    axios: deps.axios,
    apiUrl: deps.apiUrl,
    pageTitle: deps.pageTitle,
  });

  const { fruits } = stockParser.parseStock(wikitext);
  if (fruits.length === 0) {
    throw new Error('poller: parsed an empty stock, refusing to treat as a change');
  }

  const previous = stockStore.readStock(deps.stockFile);
  if (JSON.stringify(previous.fruits) === JSON.stringify(fruits)) {
    log.info?.(`poller: stock unchanged (${fruits.join(', ')})`);
    return { changed: false, fruits, record: null };
  }

  log.info(`poller: stock changed ${previous.fruits.join(', ') || '(none)'} -> ${fruits.join(', ')}`);
  const record = stockStore.writeStock({ fruits }, deps.stockFile);

  // The first record after a (re)start is just a seed — there is no previous
  // state to compare against, so no notification is sent for it.
  if (previous.fruits.length > 0) {
    await notifyStockChange({
      fruits,
      previousFruits: previous.fruits,
      topic: deps.topic,
      credentialsJson: deps.credentialsJson,
      resolver: deps.imageResolver,
    });
  }

  return { changed: true, fruits, record };
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

module.exports = { startPolling, checkStockOnce, intervalToCron, DEFAULT_INTERVAL_MS };

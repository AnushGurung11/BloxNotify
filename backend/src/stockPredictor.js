'use strict';

const { parseHistory } = require('./historyParser');
const { buildStats, backtest, rankCandidates, nextResetAt } = require('./predictor');

const DEFAULT_REFRESH_MS = 6 * 60 * 60 * 1000; // history pages change daily

/**
 * Stateful predictor service: fetches the wiki history, builds the model
 * once, and serves predictions from the cached model.
 *
 * @param {object} deps
 * @param {Function} deps.fetchHistory async () => raw history wikitext
 * @param {object} [deps.log] logger (defaults to console)
 * @param {number} [deps.refreshIntervalMs] how often to re-fetch (default 6h)
 * @returns {{refresh: Function, isReady: Function, predict: Function}}
 */
function createStockPredictor({ fetchHistory, log = console, refreshIntervalMs = DEFAULT_REFRESH_MS }) {
  let entries = [];
  let stats = null;
  let rating = { top1Accuracy: 0, top3Accuracy: 0, testedRotations: 0 };
  let lastFetchError = null;
  let timer = null;

  async function refresh() {
    try {
      const wikitext = await fetchHistory();
      entries = parseHistory(wikitext);
      stats = buildStats(entries);
      rating = backtest(entries);
      lastFetchError = null;
      log.info(
        `predictor: loaded ${entries.length} rotations ` +
        `(top-3 backtest accuracy ${rating.top3Accuracy}%, ${rating.testedRotations} tested)`,
      );
    } catch (err) {
      lastFetchError = err;
      log.error(`predictor: history fetch failed: ${err.message}`);
    }
  }

  function start() {
    refresh().then(() => {
      timer = setInterval(refresh, refreshIntervalMs);
      timer.unref?.();
    });
  }

  function stop() {
    if (timer) clearInterval(timer);
    timer = null;
  }

  function isReady() {
    return entries.length > 0;
  }

  /**
   * @param {string[]} currentFruits fruits currently in stock
   * @param {Date} [now] reference time
   * @param {Object<string, string>} [rarities] fruit name -> rarity
   * @returns {{nextResetAt: number, predictions: Array, rating: object}}
   */
  function predict(currentFruits, now = new Date(), rarities) {
    return {
      nextResetAt: nextResetAt(now),
      predictions: rankCandidates(stats, slotFor(now), currentFruits, rarities),
      rating,
    };
  }

  function slotFor(now) {
    return new Date(nextResetAt(now)).getUTCHours();
  }

  return { refresh, start, stop, isReady, predict };
}

module.exports = { createStockPredictor, DEFAULT_REFRESH_MS };
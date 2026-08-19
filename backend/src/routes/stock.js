'use strict';

const express = require('express');
const stockStore = require('../stockStore');
const fruitybloxClient = require('../fruitybloxClient');
const { HISTORY_WINDOW_DAYS } = require('../poller');

// /stock keeps a small preview of the history for backward compatibility;
// the full 7-day window is served by /stock/history.
const HISTORY_PREVIEW_LIMIT = 50;

/**
 * Converts one local snapshot into one event per dealer. Local snapshots are
 * only used when the remote bloxvalues source is unavailable.
 *
 * @param {object} entry stored snapshot ({fruits, mirageFruits, updatedAt})
 * @returns {Array<object>} 0-2 normalized events (Normal and/or Mirage)
 */
function localEntryToEvents(entry) {
  const time = Date.parse(entry && entry.updatedAt);
  if (!Number.isFinite(time)) return [];
  const timestamp = Math.floor(time / 1000);
  const timeIso = new Date(time).toISOString();
  const events = [];
  const normalItems = (entry.fruits || []).map((name) => ({ name }));
  if (normalItems.length > 0) {
    events.push({ type: 'Normal', timestamp, time: timeIso, items: normalItems });
  }
  const mirageItems = (entry.mirageFruits || []).map((name) => ({ name }));
  if (mirageItems.length > 0) {
    events.push({ type: 'Mirage', timestamp, time: timeIso, items: mirageItems });
  }
  return events;
}

/**
 * GET /stock — returns the last-known stock for both dealers (normal +
 * mirage), enriched with image URLs when a resolver is provided, plus the
 * next reset times and a preview of the recent change history.
 *
 * GET /stock/history — returns the rotation history of the last 7 days as
 * events (Normal/Mirage dealer restocks with their fruits), sourced from
 * bloxvalues.net when available and falling back to local snapshots.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {object} [deps.historyClient] optional createStockHistoryClient instance
 * @param {Date} [deps.now] reference time (tests)
 */
function createStockRouter({ stockFile, imageResolver, historyClient, now } = {}) {
  const router = express.Router();

  router.get('/stock', async (req, res) => {
    const stored = stockStore.readStock(stockFile);
    const refTime = now || new Date();

    async function enrich(dealer) {
      let items = dealer.fruits.map((name) => ({ name, imageUrl: null }));
      if (imageResolver) {
        try {
          items = await imageResolver.resolveFruits(dealer.fruits);
        } catch (err) {
          console.warn(`GET /stock: image resolution failed: ${err.message}`);
        }
      }
      return { fruits: items, updatedAt: dealer.updatedAt };
    }

    const normal = await enrich(stored.normal);
    const mirage = await enrich(stored.mirage);

    res.json({
      normal: {
        ...normal,
        nextResetAt: fruitybloxClient.nextResetAt(refTime, fruitybloxClient.NORMAL_INTERVAL_HOURS),
      },
      mirage: {
        ...mirage,
        nextResetAt: fruitybloxClient.nextResetAt(refTime, fruitybloxClient.MIRAGE_INTERVAL_HOURS),
      },
      // Backward-compatible alias: the normal dealer's stock.
      fruits: normal.fruits,
      updatedAt: normal.updatedAt,
      history: (stored.history || []).slice(0, HISTORY_PREVIEW_LIMIT),
    });
  });

  router.get('/stock/history', async (req, res) => {
    const stored = stockStore.readStock(stockFile);
    const local = (stored.history || []).flatMap(localEntryToEvents);
    local.sort((a, b) => b.timestamp - a.timestamp);

    let remote = null;
    let source = 'local';
    if (historyClient) {
      try {
        const result = await historyClient.getHistory();
        remote = result.events;
        if (remote.length > 0) source = 'bloxvalues';
      } catch (err) {
        console.warn(`GET /stock/history: bloxvalues fetch failed: ${err.message}`);
      }
    }

    // bloxvalues covers a longer span than the served window, so it replaces
    // local snapshots when available; both sources are then sliced to the
    // last HISTORY_WINDOW_DAYS days.
    const windowStartMs =
      (now || new Date()).getTime() - HISTORY_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    const events = (remote && remote.length > 0 ? remote : local).filter(
      (event) => event.timestamp * 1000 >= windowStartMs
    );
    const latest = events[0];
    res.json({
      ready: events.length > 0,
      source,
      updatedAt: latest ? latest.timestamp * 1000 : null,
      events,
    });
  });

  return router;
}

module.exports = { createStockRouter };
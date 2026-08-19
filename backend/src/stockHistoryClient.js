'use strict';

/**
 * Stock rotation history from bloxvalues.net
 * (https://bloxvalues.net/blox-fruit-stock/blox-fruit-stock-history/).
 *
 * The site's history widget loads a static JSON file:
 *   https://bloxvalues.net/wp-content/uploads/blox-fruits-calculator/stock_history.json
 *
 * Events are stock rotations: `type` is "Mirage" or "Regular" (the normal
 * dealer); `timestamp` is Unix seconds (UTC); `items` are the fruits on sale
 * with their Beli price, Robux price, image URL and detail page URL. The file
 * covers the last ~30 days.
 *
 * Events are cached in memory for `cacheTtlMs`; stale data is served when a
 * refresh fails (the history file only changes a few times per day).
 */

const HISTORY_URL =
  'https://bloxvalues.net/wp-content/uploads/blox-fruits-calculator/stock_history.json';
const DEFAULT_TTL_MS = 30 * 60 * 1000;

/**
 * Normalizes a raw bloxvalues history payload into API events.
 *
 * @param {object} payload parsed stock_history.json
 * @returns {{updated: string|null, events: Array<{type: string, timestamp: number, time: string, items: Array}>}}
 *   events sorted newest first
 */
function parseHistoryPayload(payload) {
  if (!payload || !Array.isArray(payload.events)) {
    throw new Error('bloxvalues stock history: no events array');
  }
  const events = [];
  for (const raw of payload.events) {
    if (!raw || !Array.isArray(raw.items) || raw.items.length === 0) continue;
    const timestamp = Number(raw.timestamp);
    if (!Number.isFinite(timestamp) || timestamp <= 0) continue;
    const items = raw.items
      .filter((item) => item && typeof item.name === 'string')
      .map((item) => ({
        name: item.name,
        imageUrl:
          typeof item.image === 'string' && item.image.startsWith('https://')
            ? item.image
            : null,
        price: Number.isFinite(item.price) ? item.price : null,
        robux: Number.isFinite(item.robux) ? item.robux : null,
        url: typeof item.url === 'string' ? item.url : null,
      }));
    if (items.length === 0) continue;
    events.push({
      type: raw.type === 'Mirage' ? 'Mirage' : 'Normal',
      timestamp,
      time: new Date(timestamp * 1000).toISOString(),
      items,
    });
  }
  events.sort((a, b) => b.timestamp - a.timestamp);
  return {
    updated: typeof payload.updated === 'string' ? payload.updated : null,
    events,
  };
}

/**
 * Creates a cached client for the bloxvalues history file.
 *
 * @param {object} deps
 * @param {object} deps.axios axios instance
 * @param {string} [deps.url] JSON file URL (tests)
 * @param {number} [deps.cacheTtlMs] in-memory cache lifetime
 * @param {number} [deps.timeoutMs] request timeout
 * @returns {{getHistory: Function, fetchHistory: Function, isStale: Function}}
 */
function createStockHistoryClient({
  axios,
  url = HISTORY_URL,
  cacheTtlMs = DEFAULT_TTL_MS,
  timeoutMs = 15000,
} = {}) {
  let cache = null; // { fetchedAt: number, updated: string|null, events: Array }
  let inflight = null;

  async function fetchHistory() {
    const response = await axios.get(url, { timeout: timeoutMs });
    const parsed = parseHistoryPayload(response.data);
    if (parsed.events.length === 0) {
      throw new Error('bloxvalues stock history returned no events');
    }
    cache = { fetchedAt: Date.now(), ...parsed };
    return cache;
  }

  /**
   * Returns cached events if still fresh, otherwise refetches. Serves stale
   * events when a refetch fails, throwing only when nothing is known yet.
   * @returns {Promise<{fetchedAt: number, updated: string|null, events: Array}>}
   */
  async function getHistory() {
    if (cache && Date.now() - cache.fetchedAt < cacheTtlMs) {
      return cache;
    }
    if (inflight) return inflight;
    inflight = fetchHistory()
      .catch((err) => {
        if (cache) return cache;
        throw err;
      })
      .finally(() => {
        inflight = null;
      });
    return inflight;
  }

  function isStale() {
    return cache == null || Date.now() - cache.fetchedAt >= cacheTtlMs;
  }

  return { getHistory, fetchHistory, isStale };
}

module.exports = {
  createStockHistoryClient,
  parseHistoryPayload,
  HISTORY_URL,
  DEFAULT_TTL_MS,
};

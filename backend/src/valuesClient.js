'use strict';

/**
 * Live item values from game.guide's Blox Fruits value list
 * (https://www.game.guide/blox-fruits-value-list).
 *
 * The page is a Next.js App Router site with no public API, so the values are
 * scraped from the server-rendered page. Two paths, both verified against the
 * live site:
 *
 *  1. The `self.__next_f` flight payload embeds the full dataset as escaped
 *     JSON (`"items":[...]` with id, name, normalValue, permanentValue,
 *     demand, trend, category, rarity, fruitType, imageUrl per item).
 *  2. If the payload changes shape, fall back to parsing the rendered item
 *     cards in the static HTML (name, Normal/Perm/Demand/Trend fields).
 *
 * Values are cached in memory for `cacheTtlMs` so repeated requests do not
 * hammer the site. `normalValue` is the in-game trade value; `permanentValue`
 * is the trade value of the permanent version of the item, in the same
 * in-game units as `normalValue` (game.guide's "Perm" column) — null when
 * the item has none.
 */

const VALUES_URL = 'https://www.game.guide/blox-fruits-value-list';
const IMAGE_BASE = 'https://www.game.guide';
const DEFAULT_TTL_MS = 10 * 60 * 1000; // values change hourly at most

// Inside the flight payload every quote is JSON-escaped (a literal backslash
// before it). The anchor below is that escaped form of the JSON key
// `"items":[`, built char-by-char so no text-editor escaping can strip the
// backslashes.
const BS = '\\'; // a literal backslash
const ITEMS_ANCHOR = `${BS}"items${BS}":[`;

/**
 * Extracts items from the Next.js flight payloads embedded in the page.
 *
 * The items array lives inside one of the escaped flight payload strings
 * (`self.__next_f.push([1,"N:..."]);`). Every payload string is unescaped
 * once, parsed as JSON, and the first non-empty `items` array is collected
 * from the resulting tree. (Some page variants emit an empty `items:[]`
 * placeholder payload before the real one.)
 *
 * @param {string} html
 * @returns {Array|null} parsed items or null when the payload is not present
 */
function extractItemsFromPayload(html) {
  const pushAnchor = 'self.__next_f.push([1,"';
  let searchFrom = 0;
  for (;;) {
    const anchorAt = html.indexOf(pushAnchor, searchFrom);
    if (anchorAt < 0) break;
    searchFrom = anchorAt + pushAnchor.length;
    const contentStart = html.indexOf(':', searchFrom) + 1;
    // Inside a payload string every quote is escaped (`\"`), so the literal
    // closing `"])` sequence only ever appears at the string's real end.
    const contentEnd = html.indexOf('"])', contentStart);
    if (contentEnd < 0) break;
    searchFrom = contentEnd + 2;

    const raw = html.slice(contentStart, contentEnd);
    let items;
    try {
      const unescaped = JSON.parse(`"${raw}"`);
      const tree = JSON.parse(unescaped);
      const stack = [tree];
      while (stack.length) {
        const node = stack.pop();
        if (Array.isArray(node)) {
          for (const child of node) stack.push(child);
        } else if (node && typeof node === 'object') {
          if (Array.isArray(node.items) && node.items.length > 0) {
            items = node.items;
            break;
          }
          for (const value of Object.values(node)) stack.push(value);
        }
      }
    } catch (err) {
      continue; // non-JSON payloads (module refs, scripts) are normal
    }
    if (items) {
      return items.map(normalizeItem).filter((item) => item !== null);
    }
  }
  return null;
}

const DEMAND_LEVELS = ['Very High', 'High', 'Medium', 'Low', 'Very Low'];

/**
 * Parses a formatted value like "56.50B", "812.5K" or "927.50M" to a number.
 * @param {string} text
 * @returns {number|null} null when the text is not a value ("-", "")
 */
function parseFormattedValue(text) {
  const match = /^([\d,.]+)([KMB])?$/.exec(String(text).trim());
  if (!match) return null;
  const n = Number(match[1].replace(/,/g, ''));
  if (Number.isNaN(n)) return null;
  const suffix = match[2];
  if (suffix === 'K') return n * 1e3;
  if (suffix === 'M') return n * 1e6;
  if (suffix === 'B') return n * 1e9;
  return n;
}

/**
 * Maps a raw payload item to the API shape.
 * @param {object} raw
 * @returns {object|null}
 */
function normalizeItem(raw) {
  if (!raw || typeof raw.name !== 'string') return null;
  return {
    id: typeof raw.id === 'number' ? raw.id : null,
    name: raw.name,
    normalValue: Number.isFinite(raw.normalValue) ? raw.normalValue : null,
    permanentValue:
      Number.isFinite(raw.permanentValue) && raw.permanentValue > 0
        ? raw.permanentValue
        : null,
    demand: DEMAND_LEVELS.includes(raw.demand) ? raw.demand : null,
    trend: typeof raw.trend === 'string' ? raw.trend : null,
    category: typeof raw.category === 'string' ? raw.category : null,
    rarity: typeof raw.rarity === 'string' ? raw.rarity : null,
    fruitType: typeof raw.fruitType === 'string' ? raw.fruitType : null,
    imageUrl:
      typeof raw.imageUrl === 'string' && raw.imageUrl.startsWith('/')
        ? `${IMAGE_BASE}${raw.imageUrl}`
        : null,
  };
}

/**
 * Parses one rendered item card from the static HTML into an item.
 * @param {string} card
 * @returns {object|null}
 */
function parseCard(card) {
  const name = /cos-unit-card-name">([^<]+)</.exec(card);
  const fields = {};
  const fieldRe = /cos-unit-card-field-label">(Normal|Perm|Demand|Trend):<\/span><span[^>]*>([^<]+)<\/span>/g;
  let m;
  while ((m = fieldRe.exec(card)) !== null) {
    fields[m[1].toLowerCase()] = m[2].trim();
  }
  const rarity = /cos-card-tier-badge"[^>]*>([^<]+)</.exec(card);
  const img = /src="[^"]*(\/images\/blox-fruits\/[^"]+\.webp)"/.exec(card);

  if (!name || !fields.normal) return null;
  const normalValue = parseFormattedValue(fields.normal);
  return {
    id: null,
    name: name[1].trim(),
    normalValue,
    permanentValue: parseFormattedValue(fields.perm),
    demand: DEMAND_LEVELS.includes(fields.demand) ? fields.demand : null,
    trend: fields.trend || null,
    category: null, // not rendered in the card grid
    rarity: rarity ? rarity[1].trim() : null,
    fruitType: null,
    imageUrl: img ? `${IMAGE_BASE}${img[1]}` : null,
  };
}

/**
 * Extracts items from the server-rendered card grid (fallback path).
 * @param {string} html
 * @returns {Array<object>}
 */
function extractItemsFromCards(html) {
  return html
    .split('<div class="cos-unit-card"')
    .slice(1)
    .map(parseCard)
    .filter((item) => item !== null);
}

/**
 * Parses a game.guide value list page into normalized items.
 * @param {string} html
 * @returns {Array<object>} items sorted by normalValue descending
 */
function parseValuesPage(html) {
  const items = extractItemsFromPayload(html) || extractItemsFromCards(html);
  items.sort((a, b) => (b.normalValue || 0) - (a.normalValue || 0));
  return items;
}

/**
 * Creates a cached client for the value list.
 *
 * @param {object} deps
 * @param {object} deps.axios axios instance
 * @param {string} [deps.url] page URL (tests)
 * @param {number} [deps.cacheTtlMs] in-memory cache lifetime
 * @param {number} [deps.timeoutMs] request timeout
 * @returns {{getValues: Function, fetchValues: Function, isStale: Function}}
 */
function createValueClient({
  axios,
  url = VALUES_URL,
  cacheTtlMs = DEFAULT_TTL_MS,
  timeoutMs = 15000,
} = {}) {
  let cache = null; // { fetchedAt: number, items: Array }
  let inflight = null;

  async function fetchValues() {
    const response = await axios.get(url, { timeout: timeoutMs });
    const items = parseValuesPage(response.data);
    if (items.length === 0) {
      throw new Error('game.guide value list returned no items');
    }
    cache = { fetchedAt: Date.now(), items };
    return items;
  }

  /**
   * Returns cached values if still fresh, otherwise refetches. Serves stale
   * values when a refetch fails, throwing only when nothing is known yet.
   * @returns {Promise<Array<object>>}
   */
  async function getValues() {
    if (cache && Date.now() - cache.fetchedAt < cacheTtlMs) {
      return cache.items;
    }
    if (inflight) return inflight;
    inflight = fetchValues()
      .catch((err) => {
        if (cache) return cache.items;
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

  function getFetchedAt() {
    return cache ? cache.fetchedAt : null;
  }

  return { getValues, fetchValues, isStale, getFetchedAt };
}

module.exports = {
  createValueClient,
  parseValuesPage,
  extractItemsFromPayload,
  extractItemsFromCards,
  parseFormattedValue,
  ITEMS_ANCHOR,
  VALUES_URL,
  IMAGE_BASE,
  DEMAND_LEVELS,
  DEFAULT_TTL_MS,
};
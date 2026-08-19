'use strict';

/**
 * Fetches the live Blox Fruits stock from https://fruityblox.com/stock.
 *
 * FruityBlox pulls dealer stock automatically from the in-game shop (Normal
 * dealer rotates every 4 hours, Mirage dealer every 2 hours), so it is much
 * fresher than the community-edited wiki page.
 *
 * The site is a Next.js app without a public JSON API — the stock is
 * server-rendered into the HTML, both as escaped JSON props embedded in the
 * page's `self.__next_f.push(...)` payloads and as rendered card markup. We
 * try the embedded JSON first and fall back to parsing the rendered cards.
 *
 * Pure functions (no network) are exported for unit testing.
 */

const STOCK_URL = 'https://fruityblox.com/stock';
const FRUITYBLOX_ORIGIN = 'https://fruityblox.com';
const IMAGE_BASE = `${FRUITYBLOX_ORIGIN}/images/fruits`;

// Stock resets are aligned to these UTC times: normal every 4 hours,
// mirage every 2 hours.
const NORMAL_INTERVAL_HOURS = 4;
const MIRAGE_INTERVAL_HOURS = 2;

/**
 * Decodes the escaped JSON fragments the Next.js payload embeds (e.g.
 * `{\"name\":\"Rocket\",...}`) into real JSON text.
 *
 * @param {string} fragment escaped JSON string from the payload
 * @returns {string} JSON.parse-able text
 */
function unescapePayloadJson(fragment) {
  return fragment
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\');
}

/**
 * Extracts the `{normal: [...], mirage: [...]}` props object from the
 * embedded Next.js payload if present.
 *
 * @param {string} html
 * @returns {{normal: Array, mirage: Array}|null}
 */
function extractStockProps(html) {
  const match = html.match(/\{\\"normal\\":(\[.*?\]),\\"mirage\\":(\[.*?\])/);
  if (!match) return null;
  try {
    return {
      normal: JSON.parse(unescapePayloadJson(match[1])),
      mirage: JSON.parse(unescapePayloadJson(match[2])),
    };
  } catch (err) {
    return null;
  }
}

/**
 * Extracts fruit cards from one rendered dealer section.
 *
 * Each card is an <a href="/items/<slug>"> block containing an <img> with
 * `src="/images/fruits/<slug>.webp"` and `alt="<Name>"`, an <h3> with the
 * name, a <span> with the type, and price spans (Beli + Robux).
 *
 * @param {string} sectionHtml raw HTML of the section
 * @returns {Array<{name: string, price: number, robuxPrice: number, type: string, image: string}>}
 */
function parseSectionCards(sectionHtml) {
  const cards = [];
  const cardRe = /<a href="\/items\/([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
  let cardMatch;
  while ((cardMatch = cardRe.exec(sectionHtml)) !== null) {
    const slug = cardMatch[1];
    const body = cardMatch[2];

    const nameMatch = body.match(/<h3[^>]*>([^<]+)<\/h3>/);
    const typeMatch = body.match(/<span[^>]*>([^<]+)<\/span>/);
    const prices = [...body.matchAll(/>([\d,]{2,})</g)]
      .map((m) => Number(m[1].replace(/,/g, '')))
      .filter((n) => n > 0);

    const name = nameMatch ? nameMatch[1].trim() : null;
    if (!name) continue;

    cards.push({
      name,
      price: prices[0] || 0,
      robuxPrice: prices[1] || 0,
      type: typeMatch ? typeMatch[1].trim() : '',
      image: `${IMAGE_BASE}/${slug}.webp`,
    });
  }
  return cards;
}

/**
 * Extracts the stock from the rendered DOM (fallback when the embedded JSON
 * is missing or malformed).
 *
 * @param {string} html
 * @returns {{normal: Array, mirage: Array}|null}
 */
function extractStockFromDom(html) {
  const sections = [...html.matchAll(/<section>([\s\S]*?)<\/section>/g)].map(
    (m) => m[1]
  );
  if (sections.length === 0) return { normal: [], mirage: [] };

  const stock = { normal: [], mirage: [] };
  for (const section of sections) {
    const heading = section.match(/<h2[^>]*>([^<]+)<\/h2>/);
    const label = heading ? heading[1].trim().toLowerCase() : '';
    const key = label.startsWith('mirage') ? 'mirage' : 'normal';
    stock[key] = parseSectionCards(section);
  }
  return stock;
}

/**
 * Converts a stock item list to fruit names only.
 *
 * @param {Array<{name: string}>} items
 * @returns {string[]}
 */
function itemNames(items) {
  return (items || []).map((item) => item.name).filter(Boolean);
}

/**
 * Computes the next epoch-aligned reset boundary for a dealer with the given
 * rotation interval (e.g. 4h normal, 2h mirage). Mirrors how FruityBlox's own
 * countdown works (`now % interval`).
 *
 * @param {Date} now reference time
 * @param {number} intervalHours rotation interval
 * @returns {number} epoch milliseconds of the next reset
 */
function nextResetAt(now, intervalHours) {
  const ms = intervalHours * 3600 * 1000;
  const nowMs = now.getTime();
  const remainder = nowMs % ms;
  return nowMs + (ms - remainder);
}

/**
 * Parses a raw FruityBlox stock page into a structured snapshot.
 *
 * @param {string} html raw page HTML
 * @param {Date} [now] reference time (used for reset computation)
 * @returns {{normal: Array, mirage: Array, nextResetAt: number, mirageNextResetAt: number}}
 *   `normal`/`mirage` are item lists ({name, price, robuxPrice, type, image}).
 */
function parseStockPage(html, now = new Date()) {
  const props = extractStockProps(html) || extractStockFromDom(html) || {
    normal: [],
    mirage: [],
  };
  return {
    normal: props.normal,
    mirage: props.mirage,
    nextResetAt: nextResetAt(now, NORMAL_INTERVAL_HOURS),
    mirageNextResetAt: nextResetAt(now, MIRAGE_INTERVAL_HOURS),
  };
}

/**
 * Fetches the live stock from FruityBlox.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance used for HTTP
 * @param {string} [deps.url] page URL (tests)
 * @returns {Promise<{normal: Array, mirage: Array, nextResetAt: number, mirageNextResetAt: number}>}
 */
async function fetchStockPage({ axios, url = STOCK_URL }) {
  const { data } = await axios.get(url, {
    headers: {
      'User-Agent': 'BloxNotify/1.0 (community stock tracker)',
      Accept: 'text/html',
    },
    timeout: 20000,
  });

  if (typeof data !== 'string' || data.length === 0) {
    throw new Error('fruitybloxClient: response contained no HTML');
  }

  const stock = parseStockPage(data);
  if (stock.normal.length === 0 && stock.mirage.length === 0) {
    throw new Error('fruitybloxClient: could not find any stock in the page');
  }
  return stock;
}

module.exports = {
  fetchStockPage,
  parseStockPage,
  extractStockProps,
  extractStockFromDom,
  parseSectionCards,
  nextResetAt,
  itemNames,
  STOCK_URL,
  IMAGE_BASE,
  NORMAL_INTERVAL_HOURS,
  MIRAGE_INTERVAL_HOURS,
};
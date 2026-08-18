'use strict';

const { WIKI_API, fetchStockWikitext } = require('./wikiClient');

const CURRENT_MONTH_PAGE = 'History_of_Stock';
const YEAR_PAGE = (year) => `History_of_Stock/${year}`;

/**
 * Fetches the full stock history: all completed year pages plus the
 * current-month page. Fetched sequentially so the wiki never sees parallel
 * requests from this process.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance used for HTTP
 * @param {string} [deps.apiUrl] MediaWiki API base URL
 * @param {number} [deps.currentYear] the current year (defaults to the
 *   server's local year, used for tests)
 * @returns {Promise<string>} concatenated wikitext of all history pages
 */
async function fetchHistoryWikitext({ axios, apiUrl = WIKI_API, currentYear = new Date().getFullYear() }) {
  const pages = [CURRENT_MONTH_PAGE];
  for (let year = 2020; year < currentYear; year += 1) {
    pages.push(YEAR_PAGE(year));
  }

  const parts = [];
  for (const page of pages) {
    try {
      const wikitext = await fetchStockWikitext({ axios, apiUrl, pageTitle: page });
      parts.push(wikitext);
    } catch (err) {
      // A missing year page must not break the whole fetch.
      console.warn(`historyClient: could not fetch ${page}: ${err.message}`);
    }
  }
  return parts.join('\n');
}

module.exports = { fetchHistoryWikitext, CURRENT_MONTH_PAGE, YEAR_PAGE };
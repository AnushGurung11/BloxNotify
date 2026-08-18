'use strict';

const WIKI_API = 'https://blox-fruits.fandom.com/api.php';
const DEFAULT_PAGE = 'Blox_Fruits_"Stock"';

/**
 * Fetches the raw wikitext of the stock page from the MediaWiki API.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance used for HTTP
 * @param {string} [deps.apiUrl] MediaWiki API base URL
 * @param {string} [deps.pageTitle] page to fetch
 * @returns {Promise<string>} raw wikitext
 */
async function fetchStockWikitext({ axios, apiUrl = WIKI_API, pageTitle = DEFAULT_PAGE }) {
  const { data } = await axios.get(apiUrl, {
    params: {
      action: 'parse',
      page: pageTitle,
      prop: 'wikitext',
      format: 'json',
    },
    headers: {
      'User-Agent': 'BloxNotify/1.0 (community stock tracker)',
    },
  });

  const wikitext = data && data.parse && data.parse.wikitext && data.parse.wikitext['*'];
  if (typeof wikitext !== 'string' || wikitext.length === 0) {
    throw new Error('wikiClient: response contained no wikitext');
  }
  return wikitext;
}

module.exports = { fetchStockWikitext, WIKI_API, DEFAULT_PAGE };

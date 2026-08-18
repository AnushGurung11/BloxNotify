'use strict';

/**
 * Parses the raw wikitext of the "Blox Fruits "Stock"" page and extracts the
 * current stock's fruit names.
 *
 * The wiki page renders the stock through the {{Stock/Main}} template, e.g.:
 *
 *   {{Stock/Header}}{{Stock/Main
 *   |Current = Spring, Flame, Light
 *   |Last    = Blade, Dark, Spider
 *   |Before  = Blade, Ice, Mammoth
 *   }}
 *
 * Only the "Current" section is of interest; "Last" and "Before" are ignored.
 *
 * Pure function: no network, no filesystem, fully unit-testable.
 *
 * @param {string} wikitext raw wikitext returned by the MediaWiki API
 * @returns {{ fruits: string[] }} current stock fruit names
 */
function parseStock(wikitext) {
  if (typeof wikitext !== 'string' || wikitext.length === 0) {
    return { fruits: [] };
  }

  const mainTemplate = wikitext.match(/\{\{\s*Stock\/Main([\s\S]*?)\}\}/i);
  if (!mainTemplate) {
    return { fruits: [] };
  }

  const body = mainTemplate[1];
  const currentField = body.match(/^\|\s*Current\s*=\s*([^|\n]+)/im);
  if (!currentField) {
    return { fruits: [] };
  }

  const fruits = currentField[1]
    .split(',')
    .map((name) => name.trim())
    .filter((name) => name.length > 0);

  return { fruits };
}

module.exports = { parseStock };

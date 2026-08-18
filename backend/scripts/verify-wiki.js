'use strict';

/**
 * Manual verification script: fetches the live wiki page, parses the current
 * stock, and resolves fruit image URLs. Run with:
 *
 *   npm run verify:wiki
 */

require('dotenv').config();

const axios = require('axios');
const wikiClient = require('../src/wikiClient');
const stockParser = require('../src/stockParser');
const { createImageResolver } = require('../src/fruitImages');

(async () => {
  const apiUrl = process.env.WIKI_API_URL;
  const pageTitle = process.env.WIKI_PAGE;
  const resolver = createImageResolver({ axios, apiUrl });

  console.log(`Fetching wikitext from ${apiUrl || wikiClient.WIKI_API} ...`);
  const wikitext = await wikiClient.fetchStockWikitext({ axios, apiUrl, pageTitle });

  const { fruits } = stockParser.parseStock(wikitext);
  if (fruits.length === 0) {
    console.error('Parsed an empty stock — check the wiki page format!');
    process.exit(1);
  }

  console.log(`Current stock (${fruits.length}):`);
  const items = await resolver.resolveFruits(fruits);
  for (const { name, imageUrl } of items) {
    console.log(`  - ${name}  ${imageUrl || '(no image found)'}`);
  }
})().catch((err) => {
  console.error(`Verification failed: ${err.message}`);
  process.exit(1);
});

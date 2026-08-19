'use strict';

/**
 * Manual verification script: fetches the live FruityBlox stock page, parses
 * the current normal + mirage stock, and prints the resolved image URLs. Run
 * with:
 *
 *   npm run verify:stock
 */

require('dotenv').config();

const axios = require('axios');
const { fetchStockPage } = require('../src/fruitybloxClient');
const { createImageResolver, imageUrlFor } = require('../src/fruitImages');

(async () => {
  console.log('Fetching https://fruityblox.com/stock ...');
  const stock = await fetchStockPage({ axios });

  for (const dealer of ['normal', 'mirage']) {
    const items = stock[dealer];
    if (items.length === 0) {
      console.error(`Parsed an empty ${dealer} stock — check the page format!`);
      process.exit(1);
    }
    console.log(`\n${dealer.toUpperCase()} stock (${items.length}):`);
    for (const item of items) {
      console.log(`  - ${item.name}  ${imageUrlFor(item.name)}`);
    }
  }

  console.log(`\nNext normal reset: ${new Date(stock.nextResetAt).toISOString()}`);
  console.log(`Next mirage reset: ${new Date(stock.mirageNextResetAt).toISOString()}`);
})().catch((err) => {
  console.error(`Verification failed: ${err.message}`);
  process.exit(1);
});
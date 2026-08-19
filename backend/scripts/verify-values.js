'use strict';

/**
 * One-off verification: fetch the live game.guide value list and print a
 * summary. Run with `npm run verify:values`.
 */

require('dotenv').config();

const axios = require('axios');
const { parseValuesPage, VALUES_URL } = require('../src/valuesClient');

(async () => {
  const url = process.env.VALUES_URL || VALUES_URL;
  console.log(`Fetching ${url} ...`);
  const response = await axios.get(url, { timeout: 20000 });
  const items = parseValuesPage(response.data);
  console.log(`Parsed ${items.length} items`);
  if (items.length === 0) {
    console.error('No items found — the page structure may have changed');
    process.exitCode = 1;
    return;
  }

  const categories = {};
  for (const item of items) {
    categories[item.category || 'unknown'] = (categories[item.category || 'unknown'] || 0) + 1;
  }
  console.log('Categories:', JSON.stringify(categories));

  console.log('Top 5 by value:');
  for (const item of items.slice(0, 5)) {
    console.log(
      `  ${item.name} | value ${item.normalValue} | perm ${item.permanentValue} ` +
      `| demand ${item.demand} | rarity ${item.rarity} | img ${item.imageUrl}`,
    );
  }

  const withImage = items.filter((i) => i.imageUrl).length;
  const withDemand = items.filter((i) => i.demand).length;
  console.log(`images: ${withImage}/${items.length}, demand: ${withDemand}/${items.length}`);
})();
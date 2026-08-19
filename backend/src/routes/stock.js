'use strict';

const express = require('express');
const stockStore = require('../stockStore');
const fruitybloxClient = require('../fruitybloxClient');

/**
 * GET /stock — returns the last-known stock for both dealers (normal +
 * mirage), enriched with image URLs when a resolver is provided, plus the
 * next reset times and the recent change history.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {Date} [deps.now] reference time (tests)
 */
function createStockRouter({ stockFile, imageResolver, now } = {}) {
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
      history: stored.history || [],
    });
  });

  return router;
}

module.exports = { createStockRouter };
'use strict';

const express = require('express');
const stockStore = require('../stockStore');

/**
 * GET /stock — returns the last-known stock, enriched with image URLs when a
 * resolver is provided. Returns empty fruits when nothing has been recorded.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 */
function createStockRouter({ stockFile, imageResolver } = {}) {
  const router = express.Router();

  router.get('/stock', async (req, res) => {
    const { fruits, updatedAt } = stockStore.readStock(stockFile);

    let items = fruits.map((name) => ({ name, imageUrl: null }));
    if (imageResolver) {
      try {
        items = await imageResolver.resolveFruits(fruits);
      } catch (err) {
        console.warn(`GET /stock: image resolution failed: ${err.message}`);
      }
    }

    res.json({ fruits: items, updatedAt });
  });

  return router;
}

module.exports = { createStockRouter };

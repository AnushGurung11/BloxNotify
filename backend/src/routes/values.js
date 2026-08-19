'use strict';

const express = require('express');

/**
 * GET /values — live values for all tradable items (fruits, gamepasses,
 * limiteds) scraped from game.guide's Blox Fruits value list.
 *
 * Response shape:
 *   { ready: true, updatedAt, items: [{id, name, normalValue,
 *     permanentValue, demand, trend, category, rarity, fruitType, imageUrl}] }
 * On failure with no cached data: `{ ready: false }` (200) so the app can
 * show a retry state.
 *
 * @param {object} deps
 * @param {object} [deps.valueClient] created by createValueClient
 */
function createValuesRouter({ valueClient } = {}) {
  const router = express.Router();

  router.get('/values', async (req, res) => {
    if (!valueClient) {
      res.json({ ready: false });
      return;
    }
    try {
      const items = await valueClient.getValues();
      const fetchedAt = valueClient.getFetchedAt ? valueClient.getFetchedAt() : null;
      res.json({ ready: true, updatedAt: fetchedAt, items });
    } catch (err) {
      console.warn(`GET /values: fetch failed: ${err.message}`);
      res.json({ ready: false });
    }
  });

  return router;
}

module.exports = { createValuesRouter };
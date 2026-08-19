'use strict';

const express = require('express');
const stockStore = require('../stockStore');

/**
 * GET /stock/predictions — predicted fruits for the next stock rotation,
 * based on the wiki's History of Stock pages. Predictions include fruit
 * image URLs and rarity when a resolver / value client is available, and
 * always include a few Legendary/Mythical picks even when their model score
 * is low.
 *
 * Response shape:
 *   { ready: true, nextResetAt,
 *     predictions: [{name, imageUrl, confidence, rarity}],
 *     rating: {top1Accuracy, top3Accuracy, testedRotations} }
 * When the history has not been loaded yet (fetch failed at boot), returns
 * `{ ready: false }` with a 200 so the app can hide the section.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object|null} [deps.predictor] created by createStockPredictor
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {object} [deps.valueClient] optional createValueClient instance
 */
function createPredictionsRouter({ stockFile, predictor: model, imageResolver, valueClient } = {}) {
  const router = express.Router();

  router.get('/stock/predictions', async (req, res) => {
    if (!model || !model.isReady()) {
      res.json({ ready: false });
      return;
    }

    const { normal } = stockStore.readStock(stockFile);
    const rarities = await loadRarities(valueClient);
    const result = model.predict(normal.fruits, undefined, rarities);

    const attachRarity = (prediction) => ({
      ...prediction,
      rarity: rarities ? rarities[prediction.name] || null : null,
    });

    let predictions = result.predictions.map(attachRarity);
    if (imageResolver) {
      try {
        const items = await imageResolver.resolveFruits(
          result.predictions.map((p) => p.name)
        );
        predictions = result.predictions.map((p, i) => ({
          ...attachRarity(p),
          imageUrl: items[i].imageUrl,
        }));
      } catch (err) {
        console.warn(`GET /stock/predictions: image resolution failed: ${err.message}`);
      }
    }

    res.json({ ready: true, ...result, predictions });
  });

  return router;
}

/**
 * Builds a fruit name -> rarity map from the value list (best effort: names
 * must match exactly; mismatches simply leave the fruit unranked).
 *
 * @param {object|null} valueClient
 * @returns {Promise<Object<string, string>|undefined>}
 */
async function loadRarities(valueClient) {
  if (!valueClient) return undefined;
  try {
    const items = await valueClient.getValues();
    const map = {};
    for (const item of items) {
      if (item.category === 'Fruits' && item.rarity) {
        map[item.name] = item.rarity;
      }
    }
    return map;
  } catch (err) {
    console.warn(`GET /stock/predictions: value list unavailable (${err.message})`);
    return undefined;
  }
}

module.exports = { createPredictionsRouter };
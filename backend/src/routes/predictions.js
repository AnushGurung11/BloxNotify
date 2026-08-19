'use strict';

const express = require('express');
const stockStore = require('../stockStore');
const predictor = require('../predictor');

/**
 * GET /stock/predictions — predicted fruits for the next stock rotation,
 * based on the wiki's History of Stock pages. Predictions include fruit
 * image URLs when a resolver is provided, and the response ranks the UTC
 * slots with the best historical stock.
 *
 * Response shape:
 *   { ready: true, nextResetAt, predictions: [{name, imageUrl, confidence}],
 *     rating: {top1Accuracy, top3Accuracy, testedRotations},
 *     bestSlots: [{hour, premiumCount, rotations, score}] }
 * When the history has not been loaded yet (fetch failed at boot), returns
 * `{ ready: false }` with a 200 so the app can hide the section.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object|null} [deps.predictor] created by createPredictor
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 */
function createPredictionsRouter({ stockFile, predictor: model, imageResolver } = {}) {
  const router = express.Router();

  router.get('/stock/predictions', async (req, res) => {
    if (!model || !model.isReady()) {
      res.json({ ready: false });
      return;
    }

    const { normal } = stockStore.readStock(stockFile);
    const result = model.predict(normal.fruits);

    let predictions = result.predictions;
    if (imageResolver) {
      try {
        const items = await imageResolver.resolveFruits(
          result.predictions.map((p) => p.name)
        );
        predictions = result.predictions.map((p, i) => ({
          ...p,
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

module.exports = { createPredictionsRouter };
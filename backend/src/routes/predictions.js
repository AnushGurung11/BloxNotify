'use strict';

const express = require('express');
const stockStore = require('../stockStore');
const predictor = require('../predictor');

/**
 * GET /stock/predictions — predicted fruits for the next stock rotation,
 * based on the wiki's History of Stock pages.
 *
 * Response shape:
 *   { ready: true, nextResetAt, predictions: [{name, confidence}], rating: {top1Accuracy, top3Accuracy, testedRotations} }
 * When the history has not been loaded yet (fetch failed at boot), returns
 * `{ ready: false }` with a 200 so the app can hide the section.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object|null} [deps.predictor] created by createPredictor
 */
function createPredictionsRouter({ stockFile, predictor: model } = {}) {
  const router = express.Router();

  router.get('/stock/predictions', (req, res) => {
    if (!model || !model.isReady()) {
      res.json({ ready: false });
      return;
    }

    const { fruits } = stockStore.readStock(stockFile);
    const result = model.predict(fruits);
    res.json({ ready: true, ...result });
  });

  return router;
}

module.exports = { createPredictionsRouter };
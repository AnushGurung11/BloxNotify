'use strict';

const path = require('path');
const express = require('express');
const { createStockRouter } = require('./routes/stock');
const { createPredictionsRouter } = require('./routes/predictions');
const { createValuesRouter } = require('./routes/values');

/**
 * Builds the Express app. Pure of side effects so Supertest can import it
 * without starting a server or a polling loop.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @param {object} [deps.predictor] optional createStockPredictor instance
 * @param {object} [deps.valueClient] optional createValueClient instance
 * @param {object} [deps.historyClient] optional createStockHistoryClient instance
 * @returns {express.Express}
 */
function createApp({ stockFile, imageResolver, predictor, valueClient, historyClient } = {}) {
  const app = express();
  app.use(express.json());

  // Lightweight liveness endpoint used by uptime keep-alive pings that keep
  // the free-tier instance awake so the poller runs continuously.
  app.get('/health', (req, res) => res.json({ ok: true }));

  app.use('/', createStockRouter({ stockFile, imageResolver, historyClient }));
  app.use('/', createPredictionsRouter({ stockFile, predictor, imageResolver, valueClient }));
  app.use('/', createValuesRouter({ valueClient }));
  return app;
}

const DEFAULT_STOCK_FILE = path.join(__dirname, '..', 'data', 'last-known-stock.json');

module.exports = { createApp, DEFAULT_STOCK_FILE };
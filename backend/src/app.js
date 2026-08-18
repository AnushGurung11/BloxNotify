'use strict';

const path = require('path');
const express = require('express');
const { createStockRouter } = require('./routes/stock');

/**
 * Builds the Express app. Pure of side effects so Supertest can import it
 * without starting a server or a polling loop.
 *
 * @param {object} deps
 * @param {string} [deps.stockFile] path to the state file
 * @param {object} [deps.imageResolver] optional createImageResolver instance
 * @returns {express.Express}
 */
function createApp({ stockFile, imageResolver } = {}) {
  const app = express();
  app.use(express.json());
  app.use('/', createStockRouter({ stockFile, imageResolver }));
  return app;
}

const DEFAULT_STOCK_FILE = path.join(__dirname, '..', 'data', 'last-known-stock.json');

module.exports = { createApp, DEFAULT_STOCK_FILE };

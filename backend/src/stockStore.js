'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_FILE = path.join(__dirname, '..', 'data', 'last-known-stock.json');

/**
 * Normalizes a stored dealer record.
 *
 * @param {object} dealer stored dealer object (may be a string[] from the
 *   legacy format, or null)
 * @returns {{ fruits: string[], updatedAt: string | null }}
 */
function normalizeDealer(dealer) {
  if (Array.isArray(dealer)) {
    return { fruits: dealer, updatedAt: null };
  }
  return {
    fruits: Array.isArray(dealer && dealer.fruits) ? dealer.fruits : [],
    updatedAt: typeof dealer.updatedAt === 'string' ? dealer.updatedAt : null,
  };
}

/**
 * Reads the last known stock from a JSON file on disk.
 *
 * @param {string} [filePath] path to the state file
 * @returns {{ normal: {fruits: string[], updatedAt: string|null}, mirage: {fruits: string[], updatedAt: string|null}, history: Array<{fruits: string[], mirageFruits?: string[], updatedAt: string|null}> }}
 *   stored stock, or an empty record when the file does not exist or is
 *   malformed. Legacy records ({fruits: [...]}) are read as the normal
 *   dealer's stock. `history` lists previous snapshots, newest first.
 */
function readStock(filePath = DEFAULT_FILE) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(raw);
    const legacy = Array.isArray(parsed.fruits);
    return {
      normal: normalizeDealer(
        legacy ? { fruits: parsed.fruits, updatedAt: parsed.updatedAt } : parsed.normal
      ),
      mirage: normalizeDealer(legacy ? [] : parsed.mirage),
      history: Array.isArray(parsed.history) ? parsed.history : [],
    };
  } catch (err) {
    if (err.code !== 'ENOENT') {
      console.warn(`stockStore: could not read ${filePath}: ${err.message}`);
    }
  }
  return { normal: { fruits: [], updatedAt: null }, mirage: { fruits: [], updatedAt: null }, history: [] };
}

/**
 * Writes the last known stock to a JSON file on disk (atomic-ish: temp file +
 * rename). Creates parent directories as needed.
 *
 * @param {{ normal?: {fruits: string[], updatedAt?: string|null}, mirage?: {fruits: string[], updatedAt?: string|null}, history?: Array }} stock
 *   record to persist
 * @param {string} [filePath] path to the state file
 * @returns {object} the persisted record
 */
function writeStock(stock, filePath = DEFAULT_FILE) {
  const record = {
    normal: {
      fruits: Array.isArray(stock.normal && stock.normal.fruits) ? stock.normal.fruits : [],
      updatedAt: new Date().toISOString(),
    },
    mirage: {
      fruits: Array.isArray(stock.mirage && stock.mirage.fruits) ? stock.mirage.fruits : [],
      updatedAt: new Date().toISOString(),
    },
    history: Array.isArray(stock.history) ? stock.history : [],
  };

  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const tmpPath = `${filePath}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(record, null, 2), 'utf8');
  fs.renameSync(tmpPath, filePath);

  return record;
}

module.exports = { readStock, writeStock, DEFAULT_FILE };
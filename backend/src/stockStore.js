'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_FILE = path.join(__dirname, '..', 'data', 'last-known-stock.json');

/**
 * Reads the last known stock from a JSON file on disk.
 *
 * @param {string} [filePath] path to the state file
 * @returns {{ fruits: string[], updatedAt: string | null }} stored stock, or an
 *   empty record when the file does not exist or is malformed.
 */
function readStock(filePath = DEFAULT_FILE) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed.fruits)) {
      return {
        fruits: parsed.fruits,
        updatedAt: typeof parsed.updatedAt === 'string' ? parsed.updatedAt : null,
      };
    }
  } catch (err) {
    if (err.code !== 'ENOENT') {
      console.warn(`stockStore: could not read ${filePath}: ${err.message}`);
    }
  }
  return { fruits: [], updatedAt: null };
}

/**
 * Writes the last known stock to a JSON file on disk (atomic-ish: temp file +
 * rename). Creates parent directories as needed.
 *
 * @param {{ fruits: string[] }} stock record to persist
 * @param {string} [filePath] path to the state file
 * @returns {{ fruits: string[], updatedAt: string }} the persisted record
 */
function writeStock(stock, filePath = DEFAULT_FILE) {
  const record = {
    fruits: Array.isArray(stock.fruits) ? stock.fruits : [],
    updatedAt: new Date().toISOString(),
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

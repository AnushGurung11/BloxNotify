'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { readStock, writeStock } = require('../src/stockStore');

let tmpDir;
beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'stock-store-'));
});
afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe('stockStore', () => {
  test('write then read round-trips fruits, updatedAt and history', () => {
    const file = path.join(tmpDir, 'last-known-stock.json');
    const record = writeStock(
      {
        fruits: ['Flame', 'Light'],
        history: [{ fruits: ['Spring'], updatedAt: '2026-08-01T00:00:00.000Z' }],
      },
      file
    );

    expect(record.fruits).toEqual(['Flame', 'Light']);
    expect(record.updatedAt).toBeTruthy();
    expect(record.history).toHaveLength(1);

    const read = readStock(file);
    expect(read.fruits).toEqual(['Flame', 'Light']);
    expect(read.updatedAt).toEqual(record.updatedAt);
    expect(read.history).toEqual(record.history);
  });

  test('writeStock persists valid JSON to disk', () => {
    const file = path.join(tmpDir, 'nested', 'dir', 'stock.json');
    writeStock({ fruits: ['Ice'] }, file);

    const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    expect(raw.fruits).toEqual(['Ice']);
    expect(typeof raw.updatedAt).toBe('string');
    expect(raw.history).toEqual([]);
  });

  test('readStock returns empty record when the file does not exist', () => {
    expect(readStock(path.join(tmpDir, 'missing.json'))).toEqual({
      fruits: [],
      updatedAt: null,
      history: [],
    });
  });

  test('readStock returns empty record for malformed JSON', () => {
    const file = path.join(tmpDir, 'broken.json');
    fs.writeFileSync(file, '{not json', 'utf8');
    expect(readStock(file)).toEqual({ fruits: [], updatedAt: null, history: [] });
  });

  test('readStock ignores records with non-array fruits', () => {
    const file = path.join(tmpDir, 'bad.json');
    fs.writeFileSync(file, JSON.stringify({ fruits: 'Flame' }), 'utf8');
    expect(readStock(file)).toEqual({ fruits: [], updatedAt: null, history: [] });
  });

  test('readStock defaults history to an empty array when missing', () => {
    const file = path.join(tmpDir, 'nohist.json');
    fs.writeFileSync(file, JSON.stringify({ fruits: ['Flame'], updatedAt: 'x' }), 'utf8');
    const read = readStock(file);
    expect(read.history).toEqual([]);
  });

  test('writeStock sanitizes non-array input', () => {
    const file = path.join(tmpDir, 'sanitized.json');
    const record = writeStock({ fruits: 'nope' }, file);
    expect(record.fruits).toEqual([]);
  });
});

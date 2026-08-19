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

const emptyRecord = () => ({
  normal: { fruits: [], updatedAt: null },
  mirage: { fruits: [], updatedAt: null },
  history: [],
});

describe('stockStore', () => {
  test('write then read round-trips both dealers and history', () => {
    const file = path.join(tmpDir, 'last-known-stock.json');
    const record = writeStock(
      {
        normal: { fruits: ['Flame', 'Light'] },
        mirage: { fruits: ['Dough'] },
        history: [{ fruits: ['Spring'], updatedAt: '2026-08-01T00:00:00.000Z' }],
      },
      file
    );

    expect(record.normal.fruits).toEqual(['Flame', 'Light']);
    expect(record.mirage.fruits).toEqual(['Dough']);
    expect(record.history).toHaveLength(1);

    const read = readStock(file);
    expect(read.normal.fruits).toEqual(['Flame', 'Light']);
    expect(read.mirage.fruits).toEqual(['Dough']);
    expect(read.normal.updatedAt).toEqual(record.normal.updatedAt);
    expect(read.history).toEqual(record.history);
  });

  test('writeStock persists valid JSON to disk', () => {
    const file = path.join(tmpDir, 'nested', 'dir', 'stock.json');
    writeStock({ normal: { fruits: ['Ice'] } }, file);

    const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    expect(raw.normal.fruits).toEqual(['Ice']);
    expect(raw.mirage.fruits).toEqual([]);
    expect(typeof raw.normal.updatedAt).toBe('string');
    expect(raw.history).toEqual([]);
  });

  test('readStock returns empty record when the file does not exist', () => {
    expect(readStock(path.join(tmpDir, 'missing.json'))).toEqual(emptyRecord());
  });

  test('readStock returns empty record for malformed JSON', () => {
    const file = path.join(tmpDir, 'broken.json');
    fs.writeFileSync(file, '{not json', 'utf8');
    expect(readStock(file)).toEqual(emptyRecord());
  });

  test('readStock migrates the legacy single-dealer format', () => {
    const file = path.join(tmpDir, 'legacy.json');
    fs.writeFileSync(
      file,
      JSON.stringify({
        fruits: ['Flame', 'Light'],
        updatedAt: '2026-08-01T00:00:00.000Z',
        history: [{ fruits: ['Spring'], updatedAt: '2026-07-31T00:00:00.000Z' }],
      }),
      'utf8'
    );
    const read = readStock(file);
    expect(read.normal.fruits).toEqual(['Flame', 'Light']);
    expect(read.normal.updatedAt).toBe('2026-08-01T00:00:00.000Z');
    expect(read.mirage.fruits).toEqual([]);
    expect(read.history).toHaveLength(1);
  });

  test('readStock defaults history to an empty array when missing', () => {
    const file = path.join(tmpDir, 'nohist.json');
    fs.writeFileSync(file, JSON.stringify({ normal: { fruits: ['Flame'] } }), 'utf8');
    const read = readStock(file);
    expect(read.history).toEqual([]);
  });

  test('writeStock sanitizes non-array input', () => {
    const file = path.join(tmpDir, 'sanitized.json');
    const record = writeStock({ normal: { fruits: 'nope' } }, file);
    expect(record.normal.fruits).toEqual([]);
  });
});
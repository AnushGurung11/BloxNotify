'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const request = require('supertest');
const { createApp } = require('../src/app');

let tmpDir;
let stockFile;
let app;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'stock-route-'));
  stockFile = path.join(tmpDir, 'last-known-stock.json');
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe('GET /stock', () => {
  test('returns empty stock when nothing has been recorded', async () => {
    app = createApp({ stockFile });
    const res = await request(app).get('/stock');
    expect(res.status).toBe(200);
    expect(res.body.fruits).toEqual([]);
    expect(res.body.updatedAt).toBeNull();
  });

  test('returns the stored stock with raw names (no resolver)', async () => {
    const { writeStock } = require('../src/stockStore');
    const record = writeStock(
      {
        fruits: ['Spring', 'Flame'],
        history: [{ fruits: ['Ice'], updatedAt: '2026-08-01T00:00:00.000Z' }],
      },
      stockFile
    );
    app = createApp({ stockFile });

    const res = await request(app).get('/stock');
    expect(res.status).toBe(200);
    expect(res.body.fruits).toEqual([
      { name: 'Spring', imageUrl: null },
      { name: 'Flame', imageUrl: null },
    ]);
    expect(res.body.updatedAt).toBe(record.updatedAt);
    expect(res.body.history).toEqual([
      { fruits: ['Ice'], updatedAt: '2026-08-01T00:00:00.000Z' },
    ]);
  });

  test('enriches fruits with image URLs when a resolver is provided', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock({ fruits: ['Flame'] }, stockFile);

    const imageResolver = {
      resolveFruits: jest.fn().mockResolvedValue([
        { name: 'Flame', imageUrl: 'https://img/flame.png' },
      ]),
    };
    app = createApp({ stockFile, imageResolver });

    const res = await request(app).get('/stock');
    expect(res.body.fruits).toEqual([
      { name: 'Flame', imageUrl: 'https://img/flame.png' },
    ]);
  });

  test('falls back to raw names when the resolver fails', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock({ fruits: ['Ice'] }, stockFile);

    const imageResolver = {
      resolveFruits: jest.fn().mockRejectedValue(new Error('network down')),
    };
    app = createApp({ stockFile, imageResolver });

    const res = await request(app).get('/stock');
    expect(res.status).toBe(200);
    expect(res.body.fruits).toEqual([{ name: 'Ice', imageUrl: null }]);
  });
});

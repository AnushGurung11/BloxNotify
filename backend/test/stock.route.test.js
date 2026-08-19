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
    expect(res.body.normal.fruits).toEqual([]);
    expect(res.body.mirage.fruits).toEqual([]);
    expect(res.body.updatedAt).toBeNull();
  });

  test('returns both dealers with raw names and reset times', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock(
      {
        normal: { fruits: ['Spring', 'Flame'] },
        mirage: { fruits: ['Dough'] },
        history: [{ fruits: ['Ice'], updatedAt: '2026-08-01T00:00:00.000Z' }],
      },
      stockFile
    );
    app = createApp({ stockFile });

    const res = await request(app).get('/stock');
    expect(res.status).toBe(200);
    expect(res.body.normal.fruits).toEqual([
      { name: 'Spring', imageUrl: null },
      { name: 'Flame', imageUrl: null },
    ]);
    expect(res.body.mirage.fruits).toEqual([{ name: 'Dough', imageUrl: null }]);
    expect(res.body.fruits).toEqual(res.body.normal.fruits);
    expect(res.body.history).toEqual([
      { fruits: ['Ice'], updatedAt: '2026-08-01T00:00:00.000Z' },
    ]);
    // Reset times align to the 4h / 2h UTC boundaries.
    expect(typeof res.body.normal.nextResetAt).toBe('number');
    expect(typeof res.body.mirage.nextResetAt).toBe('number');
    expect(res.body.mirage.nextResetAt % (2 * 3600 * 1000)).toBe(0);
    expect(res.body.normal.nextResetAt % (4 * 3600 * 1000)).toBe(0);
  });

  test('enriches fruits with image URLs when a resolver is provided', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock({ normal: { fruits: ['Flame'] }, mirage: { fruits: ['Gas'] } }, stockFile);

    const imageResolver = {
      resolveFruits: jest.fn((names) =>
        Promise.resolve(names.map((name) => ({ name, imageUrl: `https://img/${name.toLowerCase()}.png` })))
      ),
    };
    app = createApp({ stockFile, imageResolver });

    const res = await request(app).get('/stock');
    expect(res.body.normal.fruits).toEqual([
      { name: 'Flame', imageUrl: 'https://img/flame.png' },
    ]);
    expect(res.body.mirage.fruits).toEqual([
      { name: 'Gas', imageUrl: 'https://img/gas.png' },
    ]);
  });

  test('falls back to raw names when the resolver fails', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock({ normal: { fruits: ['Ice'] } }, stockFile);

    const imageResolver = {
      resolveFruits: jest.fn().mockRejectedValue(new Error('network down')),
    };
    app = createApp({ stockFile, imageResolver });

    const res = await request(app).get('/stock');
    expect(res.status).toBe(200);
    expect(res.body.normal.fruits).toEqual([{ name: 'Ice', imageUrl: null }]);
  });
});

describe('GET /health', () => {
  test('returns ok for the keep-alive pinger', async () => {
    app = createApp({ stockFile });
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});
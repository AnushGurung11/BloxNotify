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

describe('GET /stock/history', () => {
  const remoteEvents = [
    {
      type: 'Mirage',
      timestamp: 1787122802,
      time: '2026-08-19T07:00:02.000Z',
      items: [{ name: 'Rocket', imageUrl: 'https://cdn/rocket.webp', price: 5000 }],
    },
    {
      type: 'Normal',
      timestamp: 1787119202,
      time: '2026-08-19T06:00:02.000Z',
      items: [{ name: 'Dough', price: 3500000 }],
    },
  ];

  test('serves bloxvalues events when the remote client is healthy', async () => {
    app = createApp({
      stockFile,
      historyClient: {
        getHistory: jest.fn().mockResolvedValue({
          fetchedAt: Date.now(),
          updated: '2026-08-19 07:00:02',
          events: remoteEvents,
        }),
      },
    });

    const res = await request(app).get('/stock/history');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      ready: true,
      source: 'bloxvalues',
      updatedAt: 1787122802000,
      events: remoteEvents,
    });
  });

  test('falls back to local snapshots when the remote client fails', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock(
      {
        normal: { fruits: ['Spring'] },
        mirage: { fruits: ['Dough'] },
        history: [
          {
            fruits: ['Ice', 'Venom'],
            mirageFruits: ['Gas'],
            updatedAt: '2026-08-18T12:30:00.000Z',
          },
          {
            fruits: [],
            mirageFruits: [],
            updatedAt: '2026-08-18T08:00:00.000Z',
          },
        ],
      },
      stockFile
    );
    app = createApp({
      stockFile,
      historyClient: {
        getHistory: jest.fn().mockRejectedValue(new Error('network down')),
      },
    });

    const res = await request(app).get('/stock/history');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
    expect(res.body.source).toBe('local');
    expect(res.body.updatedAt).toBe(Date.parse('2026-08-18T12:30:00.000Z'));
    expect(res.body.events).toEqual([
      {
        type: 'Normal',
        timestamp: Date.parse('2026-08-18T12:30:00.000Z') / 1000,
        time: '2026-08-18T12:30:00.000Z',
        items: [{ name: 'Ice' }, { name: 'Venom' }],
      },
      {
        type: 'Mirage',
        timestamp: Date.parse('2026-08-18T12:30:00.000Z') / 1000,
        time: '2026-08-18T12:30:00.000Z',
        items: [{ name: 'Gas' }],
      },
    ]);
  });

  test('serves local snapshots when no history client is wired', async () => {
    const { writeStock } = require('../src/stockStore');
    writeStock(
      { normal: { fruits: ['Spring'] }, history: [{ fruits: ['Ice'], updatedAt: '2026-08-18T08:00:00.000Z' }] },
      stockFile
    );
    app = createApp({ stockFile });

    const res = await request(app).get('/stock/history');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
    expect(res.body.source).toBe('local');
    expect(res.body.events).toHaveLength(1);
    expect(res.body.events[0].items).toEqual([{ name: 'Ice' }]);
  });

  test('returns ready=false when nothing is available', async () => {
    app = createApp({
      stockFile,
      historyClient: {
        getHistory: jest.fn().mockRejectedValue(new Error('network down')),
      },
    });

    const res = await request(app).get('/stock/history');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ready: false, source: 'local', updatedAt: null, events: [] });
  });

  test('excludes events older than the 7-day window', async () => {
    const { HISTORY_WINDOW_DAYS } = require('../src/poller');
    const nowMs = Date.now();
    const daysAgo = (days) => Math.floor((nowMs - days * 24 * 60 * 60 * 1000) / 1000);
    app = createApp({
      stockFile,
      historyClient: {
        getHistory: jest.fn().mockResolvedValue({
          updated: '2026-08-19 07:00:02',
          events: [
            {
              type: 'Normal',
              timestamp: daysAgo(HISTORY_WINDOW_DAYS + 2),
              time: new Date(nowMs - (HISTORY_WINDOW_DAYS + 2) * 24 * 60 * 60 * 1000).toISOString(),
              items: [{ name: 'Ancient' }],
            },
            {
              type: 'Mirage',
              timestamp: daysAgo(1),
              time: new Date(nowMs - 24 * 60 * 60 * 1000).toISOString(),
              items: [{ name: 'Recent' }],
            },
          ],
        }),
      },
    });

    const res = await request(app).get('/stock/history');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
    expect(res.body.events).toHaveLength(1);
    expect(res.body.events[0].items).toEqual([{ name: 'Recent' }]);
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
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const request = require('supertest');
const { createApp } = require('../src/app');
const { writeStock } = require('../src/stockStore');

let tmpDir;
let stockFile;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'predictions-route-'));
  stockFile = path.join(tmpDir, 'last-known-stock.json');
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

describe('GET /stock/predictions', () => {
  test('returns ready:false when the model has not been built', async () => {
    const app = createApp({ stockFile, predictor: null });
    const res = await request(app).get('/stock/predictions');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ready: false });
  });

  test('returns predictions computed from the current stock', async () => {
    writeStock({ normal: { fruits: ['Flame'] } }, stockFile);
    const predict = jest.fn(() => ({
      nextResetAt: Date.UTC(2026, 7, 18, 12),
      predictions: [{ name: 'Dough', confidence: 0.25 }],
      rating: { top1Accuracy: 21.4, top3Accuracy: 74.8, testedRotations: 12931 },
      bestSlots: [{ hour: 20, premiumCount: 3, rotations: 10, score: 0.3 }],
    }));
    const predictor = { isReady: () => true, predict };
    const app = createApp({ stockFile, predictor });

    const res = await request(app).get('/stock/predictions');
    expect(res.status).toBe(200);
    expect(predict).toHaveBeenCalledWith(['Flame']);
    expect(res.body).toEqual({
      ready: true,
      nextResetAt: Date.UTC(2026, 7, 18, 12),
      predictions: [{ name: 'Dough', confidence: 0.25 }],
      rating: { top1Accuracy: 21.4, top3Accuracy: 74.8, testedRotations: 12931 },
      bestSlots: [{ hour: 20, premiumCount: 3, rotations: 10, score: 0.3 }],
    });
  });

  test('enriches predictions with image URLs when a resolver is provided', async () => {
    writeStock({ normal: { fruits: ['Flame'] } }, stockFile);
    const predict = jest.fn(() => ({
      nextResetAt: Date.UTC(2026, 7, 18, 12),
      predictions: [
        { name: 'Dough', confidence: 0.25 },
        { name: 'Gas', confidence: 0.1 },
      ],
      rating: { top1Accuracy: 0, top3Accuracy: 0, testedRotations: 0 },
      bestSlots: [],
    }));
    const predictor = { isReady: () => true, predict };
    const imageResolver = {
      resolveFruits: jest.fn((names) =>
        Promise.resolve(names.map((name) => ({ name, imageUrl: `https://img/${name.toLowerCase()}.png` })))
      ),
    };
    const app = createApp({ stockFile, predictor, imageResolver });

    const res = await request(app).get('/stock/predictions');
    expect(res.status).toBe(200);
    expect(res.body.predictions).toEqual([
      { name: 'Dough', confidence: 0.25, imageUrl: 'https://img/dough.png' },
      { name: 'Gas', confidence: 0.1, imageUrl: 'https://img/gas.png' },
    ]);
    expect(imageResolver.resolveFruits).toHaveBeenCalledWith(['Dough', 'Gas']);
  });
});

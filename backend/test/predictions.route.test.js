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
    writeStock({ fruits: ['Flame'] }, stockFile);
    const predict = jest.fn(() => ({
      nextResetAt: Date.UTC(2026, 7, 18, 12),
      predictions: [{ name: 'Dough', confidence: 0.25 }],
      rating: { top1Accuracy: 21.4, top3Accuracy: 74.8, testedRotations: 12931 },
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
    });
  });
});

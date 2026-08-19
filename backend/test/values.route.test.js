'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');

const ITEMS = [
  {
    id: 93,
    name: 'Eclipse Chromatic',
    normalValue: 56500000000,
    permanentValue: null,
    demand: 'Very High',
    trend: 'Stable',
    category: 'Limiteds',
    rarity: 'Limited',
    fruitType: null,
    imageUrl: 'https://www.game.guide/images/blox-fruits/eclipse-chromatic.webp',
  },
];

describe('GET /values', () => {
  test('returns ready:false when no value client is wired', async () => {
    const app = createApp({});
    const res = await request(app).get('/values');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ready: false });
  });

  test('returns the cached value items', async () => {
    const fetchedAt = 1787054400000;
    const valueClient = {
      getValues: jest.fn(() => Promise.resolve(ITEMS)),
      getFetchedAt: () => fetchedAt,
    };
    const app = createApp({ valueClient });

    const res = await request(app).get('/values');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ready: true, updatedAt: fetchedAt, items: ITEMS });
  });

  test('returns ready:false when the fetch fails', async () => {
    const valueClient = {
      getValues: jest.fn(() => Promise.reject(new Error('network down'))),
    };
    const app = createApp({ valueClient });

    const res = await request(app).get('/values');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ready: false });
  });
});
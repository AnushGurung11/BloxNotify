'use strict';

const {
  createStockHistoryClient,
  parseHistoryPayload,
  HISTORY_URL,
} = require('../src/stockHistoryClient');

const payload = (overrides = {}) => ({
  updated: '2026-08-19 07:00:02',
  events: [
    {
      type: 'Mirage',
      time: '2026-08-19 07:00:02',
      timestamp: 1787122802,
      items: [
        {
          name: 'Rocket',
          image: 'https://bloxvalues.net/wp-content/uploads/2025/10/Rocket.webp',
          price: 5000,
          robux: 50,
          url: 'https://bloxvalues.net/common/rocket/',
        },
      ],
    },
    {
      type: 'Regular',
      time: '2026-08-19 06:00:02',
      timestamp: 1787119202,
      items: [{ name: 'Dough', price: 3500000, robux: 0, image: null }],
    },
  ],
  ...overrides,
});

describe('parseHistoryPayload', () => {
  test('normalizes events newest first with UTC ISO times', () => {
    const { updated, events } = parseHistoryPayload(payload());
    expect(updated).toBe('2026-08-19 07:00:02');
    expect(events).toHaveLength(2);
    expect(events[0]).toEqual({
      type: 'Mirage',
      timestamp: 1787122802,
      time: '2026-08-19T07:00:02.000Z',
      items: [
        {
          name: 'Rocket',
          imageUrl: 'https://bloxvalues.net/wp-content/uploads/2025/10/Rocket.webp',
          price: 5000,
          robux: 50,
          url: 'https://bloxvalues.net/common/rocket/',
        },
      ],
    });
    expect(events[0].timestamp).toBeGreaterThan(events[1].timestamp);
  });

  test('maps "Regular" events to the Normal dealer type', () => {
    const { events } = parseHistoryPayload(payload());
    expect(events[1].type).toBe('Normal');
    expect(events[1].items[0]).toEqual({
      name: 'Dough',
      imageUrl: null,
      price: 3500000,
      robux: 0,
      url: null,
    });
  });

  test('skips malformed events and items', () => {
    const { events } = parseHistoryPayload(
      payload({
        events: [
          null,
          { type: 'Regular', timestamp: 'not-a-number', items: [{ name: 'Gas' }] },
          { type: 'Mirage', timestamp: 100, items: [] },
          { type: 'Regular', timestamp: 200, items: [null, { price: 5 }] },
          { type: 'Mirage', timestamp: 300, items: [{ name: 'Flame' }] },
        ],
      })
    );
    expect(events).toHaveLength(1);
    expect(events[0].items).toEqual([
      { name: 'Flame', imageUrl: null, price: null, robux: null, url: null },
    ]);
  });

  test('throws when the events array is missing', () => {
    expect(() => parseHistoryPayload({})).toThrow('no events array');
    expect(() => parseHistoryPayload(null)).toThrow('no events array');
  });
});

describe('createStockHistoryClient', () => {
  test('fetches and caches the history', async () => {
    const axios = { get: jest.fn().mockResolvedValue({ data: payload() }) };
    const client = createStockHistoryClient({ axios });

    const first = await client.getHistory();
    expect(axios.get).toHaveBeenCalledTimes(1);
    expect(axios.get).toHaveBeenCalledWith(HISTORY_URL, expect.anything());
    expect(first.events).toHaveLength(2);
    expect(client.isStale()).toBe(false);

    const second = await client.getHistory();
    expect(axios.get).toHaveBeenCalledTimes(1); // served from cache
    expect(second).toBe(first);
  });

  test('serves stale events when a refresh fails', async () => {
    const axios = { get: jest.fn().mockResolvedValue({ data: payload() }) };
    const client = createStockHistoryClient({ axios, cacheTtlMs: -1 });
    await client.getHistory();

    axios.get.mockRejectedValue(new Error('timeout'));
    const stale = await client.getHistory();
    expect(stale.events).toHaveLength(2);
    expect(client.isStale()).toBe(true);
  });

  test('throws when nothing is cached yet and the fetch fails', async () => {
    const axios = { get: jest.fn().mockRejectedValue(new Error('timeout')) };
    const client = createStockHistoryClient({ axios });
    await expect(client.getHistory()).rejects.toThrow('timeout');
  });

  test('throws when the history file has no events', async () => {
    const axios = { get: jest.fn().mockResolvedValue({ data: { updated: 'x', events: [] } }) };
    const client = createStockHistoryClient({ axios });
    await expect(client.fetchHistory()).rejects.toThrow('no events');
  });
});

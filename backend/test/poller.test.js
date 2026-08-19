'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { checkStockOnce, intervalToCron } = require('../src/poller');
const { notifyStockChange } = require('../src/notifier');

jest.mock('../src/notifier');

const fixture = (name) => fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8');

// The poller reads the raw page HTML through axios, like the real client.
function makeAxios(html) {
  return { get: jest.fn().mockResolvedValue({ data: html }) };
}

describe('intervalToCron', () => {
  test('converts milliseconds to a seconds-granularity cron expression', () => {
    expect(intervalToCron(90000)).toBe('*/90 * * * * *');
    expect(intervalToCron(60000)).toBe('*/60 * * * * *');
  });
});

describe('checkStockOnce', () => {
  let tmpDir;
  let stockFile;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'poller-'));
    stockFile = path.join(tmpDir, 'last-known-stock.json');
    notifyStockChange.mockResolvedValue({ skipped: true });
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('records the first stock silently, then notifies on a real change', async () => {
    const axios = makeAxios(fixture('fruityblox-stock.html'));
    const result = await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });

    expect(result.changed).toEqual({ normal: true, mirage: true });
    expect(result.normal).toEqual(['Rocket', 'Spin', 'Blade', 'Quake', 'T-Rex']);
    expect(result.mirage).toEqual(['Rocket', 'Gas']);
    // First record is a seed after (re)start — no notification.
    expect(notifyStockChange).not.toHaveBeenCalled();

    const second = await checkStockOnce({
      axios: makeAxios(fixture('fruityblox-stock.html')),
      stockFile,
      log: { info() {}, error() {} },
    });
    expect(second.changed).toEqual({ normal: false, mirage: false });
    expect(notifyStockChange).not.toHaveBeenCalled();
  });

  test('notifies per dealer when a change happens after a seed', async () => {
    const axios = makeAxios(fixture('fruityblox-stock.html'));
    await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });
    notifyStockChange.mockClear();

    // Both dealers change on the second poll.
    const afterHtml = fixture('fruityblox-stock.html').replace('T-Rex', 'Dough').replace('Gas', 'Dough');
    const second = await checkStockOnce({
      axios: makeAxios(afterHtml),
      stockFile,
      log: { info() {}, error() {} },
    });

    expect(second.changed).toEqual({ normal: true, mirage: true });
    expect(notifyStockChange).toHaveBeenCalledTimes(2);
    expect(notifyStockChange).toHaveBeenCalledWith(
      expect.objectContaining({ dealer: 'normal', fruits: ['Rocket', 'Spin', 'Blade', 'Quake', 'Dough'] })
    );
    expect(notifyStockChange).toHaveBeenCalledWith(
      expect.objectContaining({ dealer: 'mirage', fruits: ['Rocket', 'Dough'] })
    );

    // The first snapshot moved into the history.
    const stored = JSON.parse(fs.readFileSync(stockFile, 'utf8'));
    expect(stored.history).toEqual([
      {
        fruits: ['Rocket', 'Spin', 'Blade', 'Quake', 'T-Rex'],
        mirageFruits: ['Rocket', 'Gas'],
        updatedAt: expect.any(String),
      },
    ]);
  });

  test('notifies only the dealer that changed', async () => {
    const axios = makeAxios(fixture('fruityblox-stock.html'));
    await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });
    notifyStockChange.mockClear();

    // Only the mirage stock changes.
    const afterHtml = fixture('fruityblox-stock.html').replace(/Gas/g, 'Rumble');
    const second = await checkStockOnce({
      axios: makeAxios(afterHtml),
      stockFile,
      log: { info() {}, error() {} },
    });

    expect(second.changed).toEqual({ normal: false, mirage: true });
    expect(notifyStockChange).toHaveBeenCalledTimes(1);
    expect(notifyStockChange).toHaveBeenCalledWith(
      expect.objectContaining({ dealer: 'mirage' })
    );
  });

  test('prunes history older than the 7-day window', async () => {
    const { HISTORY_WINDOW_DAYS } = require('../src/poller');
    const now = Date.parse('2026-08-19T12:00:00Z');
    const tooOld = new Date(
      now - (HISTORY_WINDOW_DAYS * 24 * 60 * 60 * 1000 + 60000)
    ).toISOString();
    const recent = new Date(now - 60 * 60 * 1000).toISOString();
    const { writeStock } = require('../src/stockStore');
    writeStock(
      {
        normal: { fruits: ['Old'] },
        history: [
          { fruits: ['Ancient'], updatedAt: tooOld },
          { fruits: ['RecentFruit'], updatedAt: recent },
        ],
      },
      stockFile
    );

    await checkStockOnce({
      axios: makeAxios(fixture('fruityblox-stock.html')),
      stockFile,
      log: { info() {}, error() {} },
      now: new Date(now),
    });

    const stored = JSON.parse(fs.readFileSync(stockFile, 'utf8'));
    // New head entry + the still-recent snapshot; the 7-day-old one is gone.
    expect(stored.history).toHaveLength(2);
    expect(stored.history.map((h) => h.fruits[0])).toEqual(['Old', 'RecentFruit']);
  });

  test('hard-caps history at MAX_HISTORY entries', async () => {
    const { MAX_HISTORY } = require('../src/poller');
    const now = Date.now();
    const history = [];
    for (let i = 0; i < MAX_HISTORY + 5; i++) {
      history.push({
        fruits: [`Fruit${i}`],
        updatedAt: new Date(now - i * 60 * 1000).toISOString(),
      });
    }
    const { writeStock } = require('../src/stockStore');
    writeStock({ normal: { fruits: ['Old'] }, history }, stockFile);

    await checkStockOnce({
      axios: makeAxios(fixture('fruityblox-stock.html')),
      stockFile,
      log: { info() {}, error() {} },
    });

    const stored = JSON.parse(fs.readFileSync(stockFile, 'utf8'));
    expect(stored.history).toHaveLength(MAX_HISTORY);
    expect(stored.history[0]).toEqual({
      fruits: ['Old'],
      mirageFruits: [],
      updatedAt: expect.any(String),
    });
  });

  test('does nothing when the stock is unchanged', async () => {
    const axios = makeAxios(fixture('fruityblox-stock.html'));
    await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });
    notifyStockChange.mockClear();

    const result = await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });

    expect(result.changed).toEqual({ normal: false, mirage: false });
    expect(notifyStockChange).not.toHaveBeenCalled();
  });

  test('throws when the parsed stock is empty (refuses to treat as change)', async () => {
    const axios = makeAxios('<html><body>no stock here</body></html>');
    await expect(
      checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } })
    ).rejects.toThrow('could not find any stock');
  });

  test('propagates fetch errors', async () => {
    const axios = { get: jest.fn().mockRejectedValue(new Error('timeout')) };
    await expect(
      checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } })
    ).rejects.toThrow('timeout');
  });
});
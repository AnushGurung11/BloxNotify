'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { checkStockOnce, intervalToCron } = require('../src/poller');
const { notifyStockChange } = require('../src/notifier');

jest.mock('../src/notifier');

const fixture = (name) => fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8');

function makeAxios(wikitext) {
  return { get: jest.fn().mockResolvedValue({ data: { parse: { wikitext: { '*': wikitext } } } }) };
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
    const axios = makeAxios(fixture('stock-before.wikitext'));
    const result = await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });

    expect(result.changed).toBe(true);
    expect(result.fruits).toEqual(['Spring', 'Flame', 'Light']);
    // First record is a seed after (re)start — no notification.
    expect(notifyStockChange).not.toHaveBeenCalled();

    const second = await checkStockOnce({
      axios: makeAxios(fixture('stock-after.wikitext')),
      stockFile,
      log: { info() {}, error() {} },
    });
    expect(second.changed).toBe(true);
    expect(second.fruits).toEqual(['Blade', 'Ice', 'Mammoth']);
    expect(notifyStockChange).toHaveBeenCalledWith(
      expect.objectContaining({ fruits: ['Blade', 'Ice', 'Mammoth'] })
    );

    // The first snapshot moved into the history.
    const stored = JSON.parse(fs.readFileSync(stockFile, 'utf8'));
    expect(stored.history).toEqual([
      { fruits: ['Spring', 'Flame', 'Light'], updatedAt: expect.any(String) },
    ]);
  });

  test('keeps history capped at MAX_HISTORY entries', async () => {
    const { MAX_HISTORY } = require('../src/poller');
    const history = [];
    for (let i = 0; i < MAX_HISTORY + 5; i++) {
      history.push({ fruits: [`Fruit${i}`], updatedAt: `t${i}` });
    }
    const { writeStock } = require('../src/stockStore');
    writeStock({ fruits: ['Old'], history }, stockFile);

    await checkStockOnce({
      axios: makeAxios(fixture('stock-after.wikitext')),
      stockFile,
      log: { info() {}, error() {} },
    });

    const stored = JSON.parse(fs.readFileSync(stockFile, 'utf8'));
    expect(stored.history).toHaveLength(MAX_HISTORY);
    expect(stored.history[0]).toEqual({
      fruits: ['Old'],
      updatedAt: expect.any(String),
    });
  });

  test('does nothing when the stock is unchanged', async () => {
    const axios = makeAxios(fixture('stock-before.wikitext'));
    await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });
    notifyStockChange.mockClear();

    const result = await checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } });

    expect(result.changed).toBe(false);
    expect(notifyStockChange).not.toHaveBeenCalled();
  });

  test('throws when the parsed stock is empty (refuses to treat as change)', async () => {
    const axios = makeAxios('{{Stock/Main\n|Last = Flame\n}}');
    await expect(
      checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } })
    ).rejects.toThrow('empty stock');
  });

  test('propagates wiki fetch errors', async () => {
    const axios = { get: jest.fn().mockRejectedValue(new Error('timeout')) };
    await expect(
      checkStockOnce({ axios, stockFile, log: { info() {}, error() {} } })
    ).rejects.toThrow('timeout');
  });
});

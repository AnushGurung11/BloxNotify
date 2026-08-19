'use strict';

const fs = require('fs');
const path = require('path');
const {
  parseStockPage,
  extractStockProps,
  extractStockFromDom,
  nextResetAt,
  NORMAL_INTERVAL_HOURS,
  MIRAGE_INTERVAL_HOURS,
} = require('../src/fruitybloxClient');

const fixture = (name) => fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8');

describe('extractStockProps', () => {
  test('extracts normal and mirage arrays from the embedded Next.js payload', () => {
    const props = extractStockProps(fixture('fruityblox-stock.html'));
    expect(props).not.toBeNull();
    expect(props.normal.map((i) => i.name)).toEqual(['Rocket', 'Spin', 'Blade', 'Quake', 'T-Rex']);
    expect(props.mirage.map((i) => i.name)).toEqual(['Rocket', 'Gas']);
    expect(props.normal[0]).toEqual({
      name: 'Rocket',
      price: 5000,
      robuxPrice: 50,
      type: 'Natural',
      image: '/images/fruits/rocket.webp',
    });
    expect(props.mirage[1].type).toBe('Elemental');
  });

  test('returns null when the payload is absent', () => {
    expect(extractStockProps('<html><body>hello</body></html>')).toBeNull();
  });
});

describe('extractStockFromDom', () => {
  test('parses rendered cards into normal and mirage sections', () => {
    const stock = extractStockFromDom(fixture('fruityblox-stock.html'));
    expect(stock.normal.map((i) => i.name)).toEqual(['Rocket', 'Spin', 'Blade', 'Quake', 'T-Rex']);
    expect(stock.mirage.map((i) => i.name)).toEqual(['Rocket', 'Gas']);
    expect(stock.normal[0].image).toBe('https://fruityblox.com/images/fruits/rocket.webp');
    expect(stock.normal[4].price).toBe(2700000);
    expect(stock.normal[4].robuxPrice).toBe(2350);
    expect(stock.normal[4].type).toBe('Beast');
    expect(stock.mirage[1].name).toBe('Gas');
  });

  test('returns empty arrays when no sections exist', () => {
    expect(extractStockFromDom('<html><body>nope</body></html>')).toEqual({
      normal: [],
      mirage: [],
    });
  });
});

describe('parseStockPage', () => {
  test('parses the full page and computes both reset times', () => {
    const now = new Date('2026-08-19T05:30:00.000Z');
    const stock = parseStockPage(fixture('fruityblox-stock.html'), now);

    expect(stock.normal.map((i) => i.name)).toEqual(['Rocket', 'Spin', 'Blade', 'Quake', 'T-Rex']);
    expect(stock.mirage.map((i) => i.name)).toEqual(['Rocket', 'Gas']);
    expect(stock.nextResetAt).toBe(Date.UTC(2026, 7, 19, 8));
    expect(stock.mirageNextResetAt).toBe(Date.UTC(2026, 7, 19, 6));
  });
});

describe('nextResetAt', () => {
  test('normal dealer resets on the 4-hour boundaries', () => {
    expect(nextResetAt(new Date('2026-08-19T05:59:00.000Z'), NORMAL_INTERVAL_HOURS))
      .toBe(Date.UTC(2026, 7, 19, 8));
    expect(nextResetAt(new Date('2026-08-19T08:00:00.000Z'), NORMAL_INTERVAL_HOURS))
      .toBe(Date.UTC(2026, 7, 19, 12));
    expect(nextResetAt(new Date('2026-08-19T22:00:00.000Z'), NORMAL_INTERVAL_HOURS))
      .toBe(Date.UTC(2026, 7, 20, 0));
  });

  test('mirage dealer resets on the 2-hour boundaries', () => {
    expect(nextResetAt(new Date('2026-08-19T05:30:00.000Z'), MIRAGE_INTERVAL_HOURS))
      .toBe(Date.UTC(2026, 7, 19, 6));
    expect(nextResetAt(new Date('2026-08-19T06:00:00.000Z'), MIRAGE_INTERVAL_HOURS))
      .toBe(Date.UTC(2026, 7, 19, 8));
  });
});
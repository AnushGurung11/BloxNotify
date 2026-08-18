'use strict';

const fs = require('fs');
const path = require('path');
const { parseHistory } = require('../src/historyParser');

const fixture = fs.readFileSync(path.join(__dirname, 'fixtures', 'history-sample.wikitext'), 'utf8');

describe('parseHistory', () => {
  test('parses the sample fixture into 12 ordered entries', () => {
    const entries = parseHistory(fixture);
    expect(entries).toHaveLength(12);
  });

  test('maps slots to UTC hours and dates to timestamps', () => {
    const entries = parseHistory(fixture);
    expect(entries[0]).toEqual({
      ts: Date.UTC(2025, 0, 1, 0),
      fruits: ['Spring', 'Flame', 'Ice', 'Quake', 'Dough'],
    });
    expect(entries[5]).toEqual({
      ts: Date.UTC(2025, 0, 1, 20),
      fruits: ['Ice', 'Sand', 'Rubber', 'Ghost', 'Magma'],
    });
    expect(entries[10]).toEqual({
      ts: Date.UTC(2025, 0, 2, 20),
      fruits: ['Blade', 'Ghost'],
    });
    expect(entries[11]).toEqual({
      ts: Date.UTC(2025, 1, 1, 8),
      fruits: ['Smoke', 'Flame'],
    });
  });

  test('strips bold-link markup and periods are accepted as separators', () => {
    const entries = parseHistory(fixture);
    expect(entries[2]).toEqual({
      ts: Date.UTC(2025, 0, 1, 8),
      fruits: ['Spring', 'Bomb', 'Flame', 'Shadow'],
    });
  });

  test('skips empty cells (unrecorded rotations)', () => {
    const entries = parseHistory(fixture);
    expect(entries.find((e) => e.ts === Date.UTC(2025, 0, 2, 4))).toBeUndefined();
  });

  test('sorts entries chronologically across months', () => {
    const entries = parseHistory(fixture);
    const ts = entries.map((e) => e.ts);
    expect([...ts].sort((a, b) => a - b)).toEqual(ts);
    expect(entries[11].ts).toBe(Date.UTC(2025, 1, 1, 8));
  });

  test('tolerates slot labels with stray whitespace', () => {
    const entries = parseHistory(fixture);
    // "|8:00 AM " (trailing space) in February
    expect(entries[11].ts).toBe(Date.UTC(2025, 1, 1, 8));
  });

  test('returns an empty array for garbage input', () => {
    expect(parseHistory('{{nothing}} here')).toEqual([]);
    expect(parseHistory('')).toEqual([]);
  });

  test('dedupes identical consecutive snapshots', () => {
    const doubled = fixture + '\n{| class="article-table"\n|+March 2025 Stock History\n!\n!3/1/25\n|-\n|12:00 AM\n|Blade, Ghost\n|}';
    const entries = parseHistory(doubled);
    const march = entries.filter((e) => e.ts === Date.UTC(2025, 2, 1, 0));
    expect(march).toHaveLength(1);
  });
});

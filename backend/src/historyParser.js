'use strict';

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// Stock resets happen at these fixed UTC times.
const SLOT_HOURS = [0, 4, 8, 12, 16, 20];

const SLOT_LABELS = {
  '12:00 AM': 0,
  '4:00 AM': 4,
  '8:00 AM': 8,
  '12:00 PM': 12,
  '4:00 PM': 16,
  '8:00 PM': 20,
};

/**
 * Extracts the fruit name from a wiki cell fragment, stripping bold and link
 * markup: '''[[Gas]]''' -> Gas, [[T-Rex]] -> T-Rex.
 *
 * @param {string} fragment
 * @returns {string}
 */
function cleanFruitName(fragment) {
  return fragment
    .replace(/'''/g, '')
    .replace(/\[\[([^\]|]*)(?:\|[^\]]*)?\]\]/g, '$1')
    .trim();
}

/**
 * Parses the fruits out of a single table cell.
 *
 * Cells are comma-separated fruit names; editors occasionally use periods as
 * separators too ("Spring, Bomb. Flame"), so both are handled.
 *
 * @param {string} cell raw cell content (without the leading `|`)
 * @returns {string[]} unique fruit names in order
 */
function parseCell(cell) {
  const names = [];
  const seen = new Set();
  for (const fragment of cell.split(/[.,]/)) {
    const name = cleanFruitName(fragment);
    if (name && !seen.has(name)) {
      seen.add(name);
      names.push(name);
    }
  }
  return names;
}

/**
 * Parses the wikitext of a "History of Stock" page (or several concatenated)
 * into rotation entries.
 *
 * Expected structure per month table:
 *   {| class="article-table"
 *   |+January 2025 Stock History
 *   !
 *   !1/1/25
 *   !1/2/25
 *   |-
 *   |12:00 AM
 *   |Spring, Flame, Ice, '''[[Dough]]'''
 *   |Blade, Flame, Light
 *   ...
 *
 * @param {string} wikitext raw page content
 * @returns {Array<{ts: number, fruits: string[]}>} entries sorted by
 *   timestamp ascending. `ts` is a UTC epoch millisecond; `fruits` are unique
 *   names in wiki order. Empty cells (unrecorded rotations) are skipped.
 */
function parseHistory(wikitext) {
  const entries = [];
  const lines = wikitext.split(/\r?\n/);

  let month = null; // 0-11
  let year = null;
  let dates = []; // current week's dates as {y, m, d}
  let slot = null; // hour 0-23
  let cellIndex = 0;

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (!line.startsWith('|') && !line.startsWith('!')) continue;

    const monthMatch = /^\|\+\s*(\w+)\s+(\d{4})\s+Stock History$/.exec(line);
    if (monthMatch) {
      const monthIndex = MONTHS.indexOf(monthMatch[1]);
      if (monthIndex >= 0) {
        month = monthIndex;
        year = Number(monthMatch[2]);
        dates = [];
      }
      continue;
    }

    // A bare `!` line starts a new week header row — its date lines follow.
    if (line === '!') {
      dates = [];
      continue;
    }

    const dateMatch = /^!\s*(\d{1,2})\/(\d{1,2})\/(\d{2})$/.exec(line);
    if (dateMatch) {
      dates.push({
        y: 2000 + Number(dateMatch[3]),
        m: Number(dateMatch[1]) - 1,
        d: Number(dateMatch[2]),
      });
      continue;
    }

    const slotMatch = /^\|\s*(12:00 AM|4:00 AM|8:00 AM|12:00 PM|4:00 PM|8:00 PM)\s*$/.exec(line);
    if (slotMatch) {
      slot = SLOT_LABELS[slotMatch[1]];
      cellIndex = 0;
      continue;
    }

    if (line === '|-' || line === '|}' || line.startsWith('|{')) continue;

    if (line.startsWith('|') && slot !== null && dates.length > 0) {
      const cell = line.slice(1).trim();
      const date = dates[cellIndex];
      cellIndex += 1;
      if (date && cell) {
        const fruits = parseCell(cell);
        if (fruits.length > 0) {
          entries.push({
            ts: Date.UTC(date.y, date.m, date.d, slot),
            fruits,
          });
        }
      }
    }
  }

  entries.sort((a, b) => a.ts - b.ts);

  // De-duplicate identical consecutive snapshots (rare, e.g. a slot logged
  // twice), keeping the first occurrence.
  const unique = [];
  let lastKey = null;
  for (const entry of entries) {
    const key = `${entry.ts}|${entry.fruits.join(',')}`;
    if (key !== lastKey) {
      unique.push(entry);
      lastKey = key;
    }
  }
  return unique;
}

module.exports = { parseHistory, SLOT_HOURS };
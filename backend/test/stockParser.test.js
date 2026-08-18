'use strict';

const fs = require('fs');
const path = require('path');
const { parseStock } = require('../src/stockParser');

const fixture = (name) => fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8');

describe('parseStock', () => {
  test('extracts the Current stock from real wikitext', () => {
    expect(parseStock(fixture('stock-before.wikitext'))).toEqual({
      fruits: ['Spring', 'Flame', 'Light'],
    });
  });

  test('extracts a rotated stock from real wikitext', () => {
    expect(parseStock(fixture('stock-after.wikitext'))).toEqual({
      fruits: ['Blade', 'Ice', 'Mammoth'],
    });
  });

  test('handles single-line template, odd spacing and mixed casing', () => {
    expect(parseStock(fixture('stock-messy.wikitext'))).toEqual({
      fruits: ['Dough', 'KitSune', 'T-Rex'],
    });
  });

  test('ignores Last and Before sections entirely', () => {
    const wikitext =
      '{{Stock/Main\n|Current = Flame\n|Last = Spirit, Yeti\n|Before = Gas, Dough\n}}';
    expect(parseStock(wikitext)).toEqual({ fruits: ['Flame'] });
  });

  test('returns empty fruits when the template is missing', () => {
    expect(parseStock('==Notes==\nno stock here')).toEqual({ fruits: [] });
  });

  test('returns empty fruits for empty or non-string input', () => {
    expect(parseStock('')).toEqual({ fruits: [] });
    expect(parseStock(null)).toEqual({ fruits: [] });
    expect(parseStock(undefined)).toEqual({ fruits: [] });
  });

  test('returns empty fruits when Current field is absent', () => {
    expect(parseStock('{{Stock/Main\n|Last = Flame\n}}')).toEqual({ fruits: [] });
  });
});

'use strict';

const { predict, backtest, rankCandidates, nextResetAt } = require('../src/predictor');

/** Builds a deterministic alternating history: B follows A, A follows B. */
function alternatingEntries(count, hour = 12) {
  const entries = [];
  for (let day = 1; day <= count; day += 1) {
    entries.push({
      ts: Date.UTC(2026, 7, day, hour),
      fruits: day % 2 === 1 ? ['A'] : ['B'],
    });
  }
  return entries;
}

describe('predictor', () => {
  describe('nextResetAt', () => {
    test('returns the next 4-hour slot boundary', () => {
      expect(nextResetAt(new Date('2026-08-18T07:30:00.000Z'))).toBe(Date.UTC(2026, 7, 18, 8));
      expect(nextResetAt(new Date('2026-08-18T13:00:00.000Z'))).toBe(Date.UTC(2026, 7, 18, 16));
    });

    test('rolls over to midnight UTC when the last slot passed', () => {
      expect(nextResetAt(new Date('2026-08-18T21:00:00.000Z'))).toBe(Date.UTC(2026, 7, 19, 0));
    });
  });

  describe('rankCandidates', () => {
    test('excludes fruits already in the current stock', () => {
      const entries = alternatingEntries(4);
      const stats = require('../src/predictor').buildStats(entries);
      const ranked = rankCandidates(stats, 12, ['A']);
      expect(ranked.some((p) => p.name === 'A')).toBe(false);
    });

    test('picks the fruit that historically followed the current stock', () => {
      const entries = alternatingEntries(4);
      const stats = require('../src/predictor').buildStats(entries);
      const ranked = rankCandidates(stats, 12, ['A']);
      expect(ranked[0].name).toBe('B');
      expect(ranked[0].confidence).toBeGreaterThan(0);
    });
  });

  describe('backtest', () => {
test('reaches 100% accuracy on a deterministic pattern', () => {
    const rating = backtest(alternatingEntries(6));
    expect(rating.top1Accuracy).toBe(100);
    expect(rating.top3Accuracy).toBe(100);
    // The first rotation has no history, and the first prediction after it
    // cannot rank an unseen fruit — so 4 rotations are testable.
    expect(rating.testedRotations).toBe(4);
  });

    test('reports zeros when there is not enough data', () => {
      expect(backtest([])).toEqual({
        top1Accuracy: 0,
        top3Accuracy: 0,
        testedRotations: 0,
      });
      expect(backtest([{ ts: Date.UTC(2026, 7, 1, 12), fruits: ['A'] }])).toEqual({
        top1Accuracy: 0,
        top3Accuracy: 0,
        testedRotations: 0,
      });
    });
  });

  describe('predict', () => {
    test('uses the current stock and reports the rating', () => {
      const result = predict({
        entries: alternatingEntries(6),
        currentFruits: ['A'],
        now: new Date('2026-08-20T10:00:00.000Z'), // next slot: 12:00 UTC
      });
      expect(result.predictions[0].name).toBe('B');
      expect(result.nextResetAt).toBe(Date.UTC(2026, 7, 20, 12));
      expect(result.rating.testedRotations).toBeGreaterThan(0);
    });

    test('adds Legendary/Mythical fruits when rarities are given', () => {
      const entries = [
        // B always follows A -> B is the clear top candidate.
        ...Array.from({ length: 10 }, (_, i) => ({
          ts: Date.UTC(2026, 7, 1 + i, 12),
          fruits: ['A', 'B'],
        })),
        // C and E appear often; D (Legendary) only once, so its score is low.
        { ts: Date.UTC(2026, 7, 11, 12), fruits: ['C', 'E'] },
        { ts: Date.UTC(2026, 7, 12, 12), fruits: ['C', 'E'] },
        { ts: Date.UTC(2026, 7, 13, 12), fruits: ['D'] },
      ];
      const result = predict({
        entries,
        currentFruits: ['A'],
        rarities: { B: 'Mythical', D: 'Legendary', C: 'Rare' },
        now: new Date('2026-08-20T10:00:00.000Z'), // next slot: 12:00 UTC
      });
      const names = result.predictions.map((p) => p.name);
      expect(names[0]).toBe('B');
      expect(names.slice(0, 3)).not.toContain('D');
      expect(names).toContain('D'); // appended as a Legendary pick
      expect(result.predictions).toHaveLength(4);
    });

    test('keeps a plain top-3 when no rarities are given', () => {
      const entries = [
        { ts: Date.UTC(2026, 7, 1, 12), fruits: ['A', 'B'] },
        { ts: Date.UTC(2026, 7, 2, 12), fruits: ['C', 'D'] },
        { ts: Date.UTC(2026, 7, 3, 12), fruits: ['E', 'F'] },
        { ts: Date.UTC(2026, 7, 4, 12), fruits: ['A', 'B'] },
        { ts: Date.UTC(2026, 7, 5, 12), fruits: ['C', 'D'] },
        { ts: Date.UTC(2026, 7, 6, 12), fruits: ['E', 'F'] },
      ];
      const result = predict({
        entries,
        currentFruits: ['A'],
        now: new Date('2026-08-20T10:00:00.000Z'),
      });
      expect(result.predictions).toHaveLength(3);
      expect(result.predictions[0].name).toBe('C');
    });
  });
});

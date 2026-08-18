'use strict';

/**
 * One-off: fetch the real wiki history, parse it, and print the model's
 * backtested accuracy. Run with: npm run verify:history
 */

const axios = require('axios');
const { fetchHistoryWikitext } = require('../src/historyClient');
const { parseHistory } = require('../src/historyParser');
const { buildStats, backtest, rankCandidates, nextResetAt } = require('../src/predictor');

(async () => {
  const wikitext = await fetchHistoryWikitext({ axios });
  const entries = parseHistory(wikitext);
  const stats = buildStats(entries);
  const rating = backtest(entries);
  const slot = new Date(nextResetAt(new Date())).getUTCHours();

  console.log(`Loaded ${entries.length} rotations from the wiki.`);
  console.log(`Backtest (walk-forward, ${rating.testedRotations} rotations):`);
  console.log(`  top-1 accuracy: ${rating.top1Accuracy}%`);
  console.log(`  top-3 accuracy: ${rating.top3Accuracy}%`);

  console.log(`\nTop-3 predictions for slot ${slot}:00 UTC:`);
  const ranked = rankCandidates(stats, slot, []);
  ranked.forEach((p, i) => console.log(`  ${i + 1}. ${p.name} (confidence ${(p.confidence * 100).toFixed(1)}%)`));
})().catch((err) => {
  console.error(`verify:history failed: ${err.message}`);
  process.exit(1);
});
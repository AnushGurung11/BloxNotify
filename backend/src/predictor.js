'use strict';

const { SLOT_HOURS } = require('./historyParser');

/**
 * Stock rotation prediction based on the wiki's History of Stock pages.
 *
 * Model (v1, intentionally simple and explainable): for each candidate fruit
 * the score blends
 *   - how often the fruit appears in the target UTC slot (slot affinity), and
 *   - how often the fruit followed a previous rotation containing each of the
 *     current fruits (transition affinity).
 * Fruits already in the current stock are excluded (the wiki data shows
 * immediate repeats are rare). Confidence is the score normalized across all
 * candidates.
 *
 * The rating is a strict walk-forward backtest: every historical rotation is
 * predicted using only the data before it, so the accuracy shown is what the
 * model would have achieved in production.
 */

const SLOT_PROB_WEIGHT = 0.6;
const TRANS_WEIGHT = 0.4;

// Fruits players care most about — used to rank which UTC slots historically
// carry the best stock.
const PREMIUM_FRUITS = new Set([
  'Dragon', 'Dough', 'Kitsune', 'T-Rex', 'Yeti', 'Gas', 'Control', 'Mammoth',
  'Leopard', 'Venom', 'Spirit', 'Shadow', 'Portal', 'Rumble', 'Gravity',
  'Phoenix', 'Sound', 'Pain', 'Blizzard', 'Quake', 'Love', 'Light', 'Magma',
]);

/**
 * Creates an empty model stats object.
 * @returns {object}
 */
function createStats() {
  return {
    slotFreq: new Map(), // slot -> Map(fruit -> count)
    slotTotal: new Map(), // slot -> count
    trans: new Map(), // prevFruit -> Map(nextFruit -> count)
    prevContain: new Map(), // prevFruit -> count
    rotations: 0,
    fruits: new Set(),
  };
}

/**
 * Adds one rotation to the stats, including its transition from the previous
 * rotation.
 * @param {object} stats
 * @param {{ts: number, fruits: string[]}} entry the rotation being added
 * @param {string[]} [prevFruits] fruits of the rotation before `entry`
 */
function addEntry(stats, entry, prevFruits = []) {
  const slot = new Date(entry.ts).getUTCHours();
  const slotMap = stats.slotFreq.get(slot) || new Map();
  for (const fruit of entry.fruits) {
    stats.fruits.add(fruit);
    slotMap.set(fruit, (slotMap.get(fruit) || 0) + 1);
    stats.prevContain.set(fruit, (stats.prevContain.get(fruit) || 0) + 1);
  }
  stats.slotFreq.set(slot, slotMap);
  stats.slotTotal.set(slot, (stats.slotTotal.get(slot) || 0) + 1);
  stats.rotations += 1;

  for (const prevFruit of prevFruits) {
    for (const nextFruit of entry.fruits) {
      const nextMap = stats.trans.get(prevFruit) || new Map();
      nextMap.set(nextFruit, (nextMap.get(nextFruit) || 0) + 1);
      stats.trans.set(prevFruit, nextMap);
    }
  }
}

/**
 * Builds model stats over a full entry list.
 * @param {Array<{ts: number, fruits: string[]}>} entries
 * @returns {object}
 */
function buildStats(entries) {
  const stats = createStats();
  let prevFruits = [];
  for (const entry of entries) {
    addEntry(stats, entry, prevFruits);
    prevFruits = entry.fruits;
  }
  return stats;
}

/**
 * Ranks candidate fruits for the next rotation.
 *
 * @param {object} stats model stats
 * @param {number} slot the next rotation's UTC hour
 * @param {string[]} currentFruits fruits in the current rotation
 * @returns {Array<{name: string, confidence: number}>} ranked candidates,
 *   confidence normalized over all candidates (0..1)
 */
function rankCandidates(stats, slot, currentFruits) {
  const current = new Set(currentFruits);
  const slotMap = stats.slotFreq.get(slot) || new Map();
  const slotTotal = stats.slotTotal.get(slot) || 0;

  const scores = [];
  let total = 0;
  for (const fruit of stats.fruits) {
    if (current.has(fruit)) continue;

    const slotProb = slotTotal > 0 ? (slotMap.get(fruit) || 0) / slotTotal : 0;

    let transScore = 0;
    if (currentFruits.length > 0) {
      let sum = 0;
      let count = 0;
      for (const g of currentFruits) {
        const gTotal = stats.prevContain.get(g) || 0;
        if (gTotal === 0) continue;
        const nextMap = stats.trans.get(g) || new Map();
        sum += (nextMap.get(fruit) || 0) / gTotal;
        count += 1;
      }
      transScore = count > 0 ? sum / count : 0;
    }

    const score = SLOT_PROB_WEIGHT * slotProb + TRANS_WEIGHT * transScore;
    total += score;
    scores.push({ name: fruit, score });
  }

  scores.sort((a, b) => b.score - a.score);
  return scores.slice(0, 3).map(({ name, score }) => ({
    name,
    confidence: total > 0 ? score / total : 0,
  }));
}

/**
 * Runs the walk-forward backtest: for every rotation after the first,
 * predict it from the stats of everything before it, then measure whether
 * the actual rotation contained any of the top-1 / top-3 predictions.
 *
 * @param {Array<{ts: number, fruits: string[]}>} entries sorted ascending
 * @returns {{top1Accuracy: number, top3Accuracy: number, testedRotations: number}}
 *   accuracies in percent, 0 when there is not enough data
 */
function backtest(entries) {
  const stats = createStats();
  let top1Hits = 0;
  let top3Hits = 0;
  let tested = 0;
  let prevFruits = [];

  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i];
    if (prevFruits.length > 0) {
      const slot = new Date(entry.ts).getUTCHours();
      const predicted = rankCandidates(stats, slot, prevFruits);
      if (predicted.length > 0) {
        const actual = new Set(entry.fruits);
        tested += 1;
        if (actual.has(predicted[0].name)) top1Hits += 1;
        if (predicted.some((p) => actual.has(p.name))) top3Hits += 1;
      }
    }
    addEntry(stats, entry, prevFruits);
    prevFruits = entry.fruits;
  }

  return {
    top1Accuracy: tested > 0 ? Math.round((top1Hits / tested) * 1000) / 10 : 0,
    top3Accuracy: tested > 0 ? Math.round((top3Hits / tested) * 1000) / 10 : 0,
    testedRotations: tested,
  };
}

/**
 * Computes the next stock rotation slot boundary (UTC) after `now`.
 * @param {Date} now
 * @returns {number} epoch milliseconds
 */
function nextResetAt(now) {
  const utc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  for (const hour of SLOT_HOURS) {
    const at = utc + hour * 3600 * 1000;
    if (at > now.getTime()) return at;
  }
  return utc + 24 * 3600 * 1000;
}

/**
 * Ranks the UTC rotation slots by historical stock quality: the average
 * number of premium fruits per rotation in each slot.
 *
 * @param {object} stats model stats
 * @returns {Array<{hour: number, premiumCount: number, rotations: number, score: number}>}
 *   slots sorted best first. `score` is premium fruits per rotation.
 */
function bestSlots(stats) {
  return SLOT_HOURS
    .map((hour) => {
      const slotMap = stats.slotFreq.get(hour) || new Map();
      const rotations = stats.slotTotal.get(hour) || 0;
      let premiumCount = 0;
      for (const fruit of PREMIUM_FRUITS) {
        premiumCount += slotMap.get(fruit) || 0;
      }
      return {
        hour,
        premiumCount,
        rotations,
        score: rotations > 0 ? premiumCount / rotations : 0,
      };
    })
    .sort((a, b) => b.score - a.score || b.premiumCount - a.premiumCount);
}

/**
 * Predicts the next rotation given the current stock.
 *
 * @param {object} deps
 * @param {Array<{ts: number, fruits: string[]}>} deps.entries parsed history
 * @param {string[]} deps.currentFruits fruits currently in stock
 * @param {Date} [deps.now] reference time (defaults to now)
 * @returns {{nextResetAt: number, predictions: Array<{name: string, confidence: number}>, rating: object, bestSlots: Array<{hour: number, premiumCount: number, rotations: number, score: number}>}}
 */
function predict({ entries, currentFruits, now = new Date() }) {
  const stats = buildStats(entries);
  const slot = new Date(nextResetAt(now)).getUTCHours();
  return {
    nextResetAt: nextResetAt(now),
    predictions: rankCandidates(stats, slot, currentFruits),
    rating: backtest(entries),
    bestSlots: bestSlots(stats),
  };
}

module.exports = { predict, backtest, rankCandidates, buildStats, addEntry, nextResetAt, bestSlots, PREMIUM_FRUITS };
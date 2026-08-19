'use strict';

/**
 * Resolves fruit image URLs for stock display and notifications.
 *
 * Images are served by FruityBlox at deterministic slug URLs
 * (https://fruityblox.com/images/fruits/<slug>.webp) — no API call needed,
 * unlike the wiki's imageinfo endpoint. Unknown fruits fall back to null
 * (the app shows a placeholder) rather than a wrong image.
 */

const { IMAGE_BASE } = require('./fruitybloxClient');

/**
 * Fruit name -> slug override. The general rule (lowercase, spaces to
 * dashes) covers every known fruit; keep overrides here when FruityBlox
 * names a file differently.
 */
const SLUG_OVERRIDES = {};

/**
 * @param {string} fruitName
 * @returns {string} fruityblox image slug for the fruit
 */
function slugFor(fruitName) {
  return SLUG_OVERRIDES[fruitName] || fruitName.toLowerCase().replace(/\s+/g, '-');
}

/**
 * @param {string} fruitName
 * @returns {string} full image URL for the fruit
 */
function imageUrlFor(fruitName) {
  return `${IMAGE_BASE}/${slugFor(fruitName)}.webp`;
}

/**
 * Creates an image resolver. The API mirrors the old wiki-based resolver so
 * callers are unaffected, but resolution is now synchronous URL building.
 *
 * @returns {{ resolveFruits: Function, resolveFruit: Function }}
 */
function createImageResolver() {
  async function resolveFruits(fruitNames) {
    return fruitNames.map((name) => ({ name, imageUrl: imageUrlFor(name) }));
  }

  async function resolveFruit(name) {
    return { name, imageUrl: imageUrlFor(name) };
  }

  return { resolveFruits, resolveFruit };
}

module.exports = { createImageResolver, imageUrlFor, slugFor };
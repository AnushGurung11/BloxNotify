'use strict';

/**
 * Maps fruit names to their image files on the wiki, and resolves the full
 * static image URLs through the MediaWiki imageinfo API (the hash component of
 * static.wikia.nocookie.net URLs cannot be derived statically).
 */

const WIKI_API = 'https://blox-fruits.fandom.com/api.php';
const IMAGE_BATCH_SIZE = 50;

/**
 * Known fruit name -> image file name mapping, following the wiki's
 * "<FruitName>_Fruit.png" convention used by every fruit infobox.
 * Fruits missing from this map get no image (never a wrong one).
 */
const FRUIT_IMAGE_FILES = {
  Rocket: 'Rocket_Fruit.png',
  Spin: 'Spin_Fruit.png',
  Blade: 'Blade_Fruit.png',
  Spring: 'Spring_Fruit.png',
  Bomb: 'Bomb_Fruit.png',
  Smoke: 'Smoke_Fruit.png',
  Spike: 'Spike_Fruit.png',
  Flame: 'Flame_Fruit.png',
  Falcon: 'Falcon_Fruit.png',
  Ice: 'Ice_Fruit.png',
  Sand: 'Sand_Fruit.png',
  Dark: 'Dark_Fruit.png',
  Diamond: 'Diamond_Fruit.png',
  Light: 'Light_Fruit.png',
  Rubber: 'Rubber_Fruit.png',
  Barrier: 'Barrier_Fruit.png',
  Ghost: 'Ghost_Fruit.png',
  Magma: 'Magma_Fruit.png',
  Quake: 'Quake_Fruit.png',
  Buddha: 'Buddha_Fruit.png',
  Love: 'Love_Fruit.png',
  Spider: 'Spider_Fruit.png',
  Phoenix: 'Phoenix_Fruit.png',
  Portal: 'Portal_Fruit.png',
  Rumble: 'Rumble_Fruit.png',
  Pain: 'Pain_Fruit.png',
  Blizzard: 'Blizzard_Fruit.png',
  Gravity: 'Gravity_Fruit.png',
  Mammoth: 'Mammoth_Fruit.png',
  'T-Rex': 'T-Rex_Fruit.png',
  Dough: 'Dough_Fruit.png',
  Shadow: 'Shadow_Fruit.png',
  Venom: 'Venom_Fruit.png',
  Gas: 'Gas_Fruit.png',
  Spirit: 'Spirit_Fruit.png',
  Tiger: 'Tiger_Fruit.png',
  Yeti: 'Yeti_Fruit.png',
  Kitsune: 'Kitsune_Fruit.png',
  Control: 'Control_Fruit.png',
  Dragon: 'Dragon_Fruit.png',
  Creation: 'Creation_Fruit.png',
  Sound: 'Sound_Fruit.png',
  Eagle: 'Eagle_Fruit.png',
  Lightning: 'Lightning_Fruit.png',
};

/**
 * @param {string} fruitName
 * @returns {string|null} image file name, or null if the fruit is unknown
 */
function imageFileFor(fruitName) {
  return FRUIT_IMAGE_FILES[fruitName] || null;
}

/**
 * Creates an image resolver with an in-memory cache. Resolved URLs persist for
 * the lifetime of the process; repeated requests for the same fruit hit the
 * wiki API at most once.
 *
 * @param {object} deps
 * @param {Function} deps.axios axios instance used for HTTP
 * @param {string} [deps.apiUrl] override MediaWiki API URL (tests)
 * @returns {{ resolveFruits: Function }}
 */
function createImageResolver({ axios, apiUrl = WIKI_API }) {
  const cache = new Map(); // file name -> full image URL

  async function resolveFileUrls(fileNames) {
    const missing = fileNames.filter((fileName) => !cache.has(fileName));
    for (let i = 0; i < missing.length; i += IMAGE_BATCH_SIZE) {
      const batch = missing.slice(i, i + IMAGE_BATCH_SIZE);
      const titles = batch.map((f) => `File:${f}`).join('|');
      const { data } = await axios.get(apiUrl, {
        params: {
          action: 'query',
          titles,
          prop: 'imageinfo',
          iiprop: 'url',
          format: 'json',
        },
      });

      const normalized = new Map(
        (data.query.normalized || []).map((n) => [n.from, n.to])
      );
      const pages = Object.values(data.query.pages || {});

      for (const fileName of batch) {
        const normalizedTitle = normalized.get(`File:${fileName}`) || `File:${fileName}`;
        const page = pages.find((p) => p.title === normalizedTitle);
        const info = page && page.imageinfo && page.imageinfo[0];
        if (info && info.url) {
          cache.set(fileName, info.url);
        }
      }
    }
  }

  /**
   * Resolves image URLs for a list of fruit names.
   *
   * @param {string[]} fruitNames
   * @returns {Promise<Array<{name: string, imageUrl: string|null}>>}
   */
  async function resolveFruits(fruitNames) {
    const withFile = fruitNames
      .filter((name) => imageFileFor(name))
      .map((name) => imageFileFor(name));

    await resolveFileUrls(withFile);

    return fruitNames.map((name) => {
      const file = imageFileFor(name);
      return { name, imageUrl: file ? cache.get(file) || null : null };
    });
  }

  return { resolveFruits };
}

module.exports = { createImageResolver, imageFileFor, FRUIT_IMAGE_FILES };

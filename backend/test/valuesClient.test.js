'use strict';

const {
  parseValuesPage,
  extractItemsFromPayload,
  extractItemsFromCards,
  parseFormattedValue,
  createValueClient,
} = require('../src/valuesClient');

/** Builds a fake game.guide page containing the items in a flight payload. */
function buildPayloadPage(items) {
  const tree = [
    ['$', '$L1c', null, { moduleIds: ['x'] }],
    ['$', '$L34', null, { items, children: ['$L33', '$L34'] }],
  ];
  const escaped = JSON.stringify(JSON.stringify(tree)).slice(1, -1);
  return `<html><body>
    <script>self.__next_f.push([1,"0:{\\"P\\":null}\\n"]);</script>
    <script>self.__next_f.push([1,"33:${escaped}"]);</script>
  </body></html>`;
}

const RAW_ITEMS = [
  {
    id: 93,
    slug: 'eclipse-chromatic-value-blox-fruits',
    name: 'Eclipse Chromatic',
    normalValue: 56500000000,
    permanentValue: null,
    demand: 'Very High',
    trend: 'Stable',
    category: 'Limiteds',
    rarity: 'Limited',
    fruitType: null,
    imageUrl: '/images/blox-fruits/eclipse-chromatic.webp',
  },
  {
    id: 12,
    slug: 'dragon-value-blox-fruits',
    name: 'Dragon',
    normalValue: 120000000,
    permanentValue: 4500,
    demand: 'High',
    trend: 'Increasing',
    category: 'Fruits',
    rarity: 'Mythical',
    fruitType: 'Beast',
    imageUrl: '/images/blox-fruits/dragon.webp',
  },
  {
    id: 1,
    slug: 'rocket-value-blox-fruits',
    name: 'Rocket',
    normalValue: 1000,
    permanentValue: null,
    demand: 'Low',
    trend: 'Stable',
    category: 'Fruits',
    rarity: 'Common',
    fruitType: 'Elemental',
    imageUrl: '/images/blox-fruits/rocket.webp',
  },
];

describe('extractItemsFromPayload', () => {
  test('parses items from the flight payload', () => {
    const items = extractItemsFromPayload(buildPayloadPage(RAW_ITEMS));
    expect(items).toHaveLength(3);
    expect(items[0]).toEqual({
      id: 93,
      name: 'Eclipse Chromatic',
      normalValue: 56500000000,
      permanentValue: null,
      demand: 'Very High',
      trend: 'Stable',
      category: 'Limiteds',
      rarity: 'Limited',
      fruitType: null,
      imageUrl: 'https://www.game.guide/images/blox-fruits/eclipse-chromatic.webp',
    });
  });

  test('skips an empty items placeholder payload', () => {
    const emptyPayload = JSON.stringify(
      JSON.stringify([['$', '$L34', null, { items: [] }]])
    ).slice(1, -1);
    const html = `<html>
      <script>self.__next_f.push([1,"31:${emptyPayload}"]);</script>
      ${buildPayloadPage(RAW_ITEMS)}
    </html>`;
    const items = extractItemsFromPayload(html);
    expect(items).toHaveLength(3);
  });

  test('returns null when the payload is absent', () => {
    expect(extractItemsFromPayload('<html>no payload</html>')).toBeNull();
  });
});

describe('parseFormattedValue', () => {
  test('parses K/M/B suffixes and comma grouping', () => {
    expect(parseFormattedValue('812.5K')).toBe(812500);
    expect(parseFormattedValue('927.50M')).toBe(927500000);
    expect(parseFormattedValue('56.50B')).toBe(56500000000);
    expect(parseFormattedValue('2,450')).toBe(2450);
    expect(parseFormattedValue('123')).toBe(123);
  });

  test('returns null for non-values', () => {
    expect(parseFormattedValue('-')).toBeNull();
    expect(parseFormattedValue('')).toBeNull();
    expect(parseFormattedValue('N/A')).toBeNull();
  });
});

describe('extractItemsFromCards', () => {
  test('parses the server-rendered card grid', () => {
    const html = `
      <div class="cos-unit-card">
        <div class="cos-unit-card-name">Dough</div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Normal:</span><span>55.00M</span>
        </div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Perm:</span><span>2,450</span>
        </div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Demand:</span><span>Very High</span>
        </div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Trend:</span><span>Stable</span>
        </div>
        <span class="cos-card-tier-badge">Mythical</span>
        <img src="/images/blox-fruits/dough.webp" class="object-contain"/>
      </div>
      <div class="cos-unit-card">
        <div class="cos-unit-card-name">Rocket</div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Normal:</span><span>1,000</span>
        </div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Demand:</span><span>Low</span>
        </div>
      </div>
    `;
    const items = extractItemsFromCards(html);
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({
      name: 'Dough',
      normalValue: 55000000,
      permanentValue: 2450,
      demand: 'Very High',
      rarity: 'Mythical',
      imageUrl: 'https://www.game.guide/images/blox-fruits/dough.webp',
      category: null,
    });
  });
});

describe('parseValuesPage', () => {
  test('prefers the payload and sorts by value descending', () => {
    const items = parseValuesPage(buildPayloadPage(RAW_ITEMS));
    expect(items.map((i) => i.name)).toEqual(['Eclipse Chromatic', 'Dragon', 'Rocket']);
  });

  test('falls back to the card grid when the payload is missing', () => {
    const html = `
      <div class="cos-unit-card">
        <div class="cos-unit-card-name">Rocket</div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Normal:</span><span>1,000</span>
        </div>
      </div>
      <div class="cos-unit-card">
        <div class="cos-unit-card-name">Dough</div>
        <div class="cos-unit-card-field">
          <span class="cos-unit-card-field-label">Normal:</span><span>55.00M</span>
        </div>
      </div>
    `;
    expect(parseValuesPage(html).map((i) => i.name)).toEqual(['Dough', 'Rocket']);
  });
});

describe('createValueClient', () => {
  const ok = () => Promise.resolve({ data: buildPayloadPage(RAW_ITEMS) });

  test('fetches once and serves the cache within the TTL', async () => {
    const get = jest.fn(ok);
    const client = createValueClient({ axios: { get }, cacheTtlMs: 60000 });
    await client.getValues();
    await client.getValues();
    expect(get).toHaveBeenCalledTimes(1);
    expect(client.isStale()).toBe(false);
  });

  test('refetches after the TTL expires', async () => {
    const get = jest.fn(ok);
    const client = createValueClient({ axios: { get }, cacheTtlMs: 0 });
    await client.getValues();
    await client.getValues();
    expect(get).toHaveBeenCalledTimes(2);
    expect(client.isStale()).toBe(true);
  });

  test('serves stale values when a refetch fails', async () => {
    const get = jest
      .fn()
      .mockResolvedValueOnce({ data: buildPayloadPage(RAW_ITEMS) })
      .mockRejectedValueOnce(new Error('network down'));
    const client = createValueClient({ axios: { get }, cacheTtlMs: 0 });
    const first = await client.getValues();
    const second = await client.getValues();
    expect(second).toBe(first);
  });

  test('throws when nothing is cached and the fetch fails', async () => {
    const get = jest.fn(() => Promise.reject(new Error('network down')));
    const client = createValueClient({ axios: { get } });
    await expect(client.getValues()).rejects.toThrow('network down');
    expect(client.isStale()).toBe(true);
    expect(client.getFetchedAt()).toBeNull();
  });

  test('throws when the page contains no items', async () => {
    const get = jest.fn(() => Promise.resolve({ data: '<html>nothing</html>' }));
    const client = createValueClient({ axios: { get } });
    await expect(client.getValues()).rejects.toThrow('returned no items');
  });
});
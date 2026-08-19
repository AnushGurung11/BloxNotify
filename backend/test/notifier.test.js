'use strict';

jest.mock('firebase-admin', () => {
  const mockSend = jest.fn().mockResolvedValue({ messageId: 'm1' });
  return {
    __mockSend: mockSend,
    credential: { cert: jest.fn(() => ({ client_email: 'mock' })) },
    initializeApp: jest.fn(),
    messaging: jest.fn(() => ({ send: mockSend })),
  };
});

const admin = require('firebase-admin');
const { __mockSend: mockSend } = admin;
const { buildMessage, notifyStockChange, DEFAULT_TOPIC, __resetForTest } = require('../src/notifier');

const CREDS = JSON.stringify({ project_id: 'test', client_email: 'x@x', private_key: 'k' });

describe('buildMessage', () => {
  test('builds a topic notification with title, body and fruit data', () => {
    const msg = buildMessage(
      [{ name: 'Flame', imageUrl: 'https://img/flame.png' }],
      'stock_updates'
    );

    expect(msg.topic).toBe('stock_updates');
    expect(msg.notification.title).toBe('Stock Updated!');
    expect(msg.notification.body).toBe('New stock: Flame');
    expect(msg.data.type).toBe('stock_update');
    expect(msg.data.fruits).toBe('Flame');
    expect(msg.data.imageUrls).toBe('{"Flame":"https://img/flame.png"}');
    expect(msg.android.notification.image).toBe('https://img/flame.png');
  });

  test('omits android image when no fruit has an image', () => {
    const msg = buildMessage([{ name: 'Falcon', imageUrl: null }], 'stock_updates');
    expect(msg.android.notification).toBeUndefined();
  });

  test('uses the default topic when none is given', () => {
    const msg = buildMessage([{ name: 'Ice', imageUrl: null }]);
    expect(msg.topic).toBe(DEFAULT_TOPIC);
  });

  test('labels mirage dealer notifications', () => {
    const msg = buildMessage(
      [{ name: 'Dough', imageUrl: 'https://img/dough.png' }],
      'stock_updates',
      'mirage'
    );
    expect(msg.notification.title).toBe('Mirage Stock Updated!');
    expect(msg.data.dealer).toBe('mirage');
    expect(msg.android.notification.image).toBe('https://img/dough.png');
  });
});

describe('notifyStockChange', () => {
  beforeEach(() => {
    mockSend.mockClear();
    admin.initializeApp.mockClear();
    __resetForTest();
  });

  test('sends to the topic with resolved image URLs', async () => {
    const resolver = {
      resolveFruits: jest.fn().mockResolvedValue([
        { name: 'Ice', imageUrl: 'https://img/ice.png' },
        { name: 'Mammoth', imageUrl: null },
      ]),
    };

    const result = await notifyStockChange({
      fruits: ['Ice', 'Mammoth'],
      credentialsJson: CREDS,
      resolver,
    });

    expect(result).toEqual({ skipped: false });
    expect(resolver.resolveFruits).toHaveBeenCalledWith(['Ice', 'Mammoth']);
    expect(mockSend).toHaveBeenCalledTimes(1);
    const message = mockSend.mock.calls[0][0];
    expect(message.topic).toBe('stock_updates');
    expect(message.data.fruits).toBe('Ice,Mammoth');
  });

  test('works without a resolver (raw fruit names, no images)', async () => {
    const result = await notifyStockChange({
      fruits: ['Flame'],
      credentialsJson: CREDS,
    });

    expect(result).toEqual({ skipped: false });
    expect(mockSend.mock.calls[0][0].data.fruits).toBe('Flame');
    expect(mockSend.mock.calls[0][0].android.notification).toBeUndefined();
  });

  test('skips sending when credentials are missing', async () => {
    const result = await notifyStockChange({ fruits: ['Flame'], credentialsJson: undefined });

    expect(result).toEqual({ skipped: true });
    expect(mockSend).not.toHaveBeenCalled();
  });

  test('skips sending on invalid credentials JSON', async () => {
    const result = await notifyStockChange({
      fruits: ['Flame'],
      credentialsJson: 'not json',
    });

    expect(result).toEqual({ skipped: true });
    expect(mockSend).not.toHaveBeenCalled();
  });
});

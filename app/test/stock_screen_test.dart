import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/screens/stock_screen.dart';
import 'package:blox_notify/services/stock_api.dart';
import 'package:blox_notify/services/update_service.dart';

StockApi _apiWith(MockClient client) => StockApi(
      client: client,
      baseUrl: 'http://test.local',
    );

/// Pumps frames without waiting for the countdown timers to stop (they tick
/// forever, so pumpAndSettle would time out).
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _stockJson({
  List<Map<String, dynamic>>? normalFruits,
  List<Map<String, dynamic>>? mirageFruits,
  String? updatedAt,
  int? nextResetAt,
  List<Map<String, dynamic>>? history,
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return {
    'normal': {
      'fruits': normalFruits ?? _fruits,
      'updatedAt': updatedAt ?? '2026-08-18T12:00:00.000Z',
      'nextResetAt': nextResetAt ?? now + 2 * 3600 * 1000,
    },
    'mirage': {
      'fruits': mirageFruits ?? const [],
      'updatedAt': updatedAt ?? '2026-08-18T12:00:00.000Z',
      'nextResetAt': nextResetAt ?? now + 3600 * 1000,
    },
    'history': history ?? const [],
  };
}

MockClient _mockStockResponse(Map<String, dynamic> body) {
  return MockClient((request) async {
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

const _fruits = [
  {'name': 'Spring', 'imageUrl': null},
  {'name': 'Flame', 'imageUrl': 'http://test.local/flame.png'},
  {'name': 'Light', 'imageUrl': null},
];

const _mirageFruits = [
  {'name': 'Dough', 'imageUrl': 'http://test.local/dough.png'},
  {'name': 'Gas', 'imageUrl': null},
];

void main() {
  Future<void> pumpStockScreen(WidgetTester tester, StockApi api) async {
    await tester.pumpWidget(MaterialApp(home: StockScreen(stockApi: api)));
    await pumpFrames(tester);
  }

  testWidgets('renders a fruit tile per fruit with names and images',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson()));

    await pumpStockScreen(tester, api);

    expect(find.text('Spring'), findsOneWidget);
    expect(find.text('Flame'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows the last-updated timestamp', (tester) async {
    final api = _apiWith(
      _mockStockResponse(_stockJson(updatedAt: '2026-08-18T12:00:00.000Z')),
    );

    await pumpStockScreen(tester, api);

    expect(find.textContaining('Last updated:'), findsOneWidget);
  });

  testWidgets('shows dealer sections with a countdown', (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson(
      mirageFruits: _mirageFruits,
      nextResetAt:
          DateTime.now().toUtc().millisecondsSinceEpoch + 2 * 3600 * 1000,
    )));

    await pumpStockScreen(tester, api);

    expect(find.text('Normal Dealer'), findsOneWidget);
    expect(find.text('Mirage Dealer'), findsOneWidget);
    // A HH:MM:SS countdown renders for each dealer.
    final countdown = tester
        .widget<Text>(find.textContaining('Next rotation in').first)
        .data!;
    expect(RegExp(r'^Next rotation in \d{2}:\d{2}:\d{2}$').hasMatch(countdown),
        isTrue);
    expect(find.textContaining('Next rotation in'), findsNWidgets(2));
  });

  test('formatCountdown uses HH:MM:SS', () {
    expect(formatCountdown(const Duration(hours: 2)), '02:00:00');
    expect(formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 7)),
        '02:05:07');
    expect(formatCountdown(const Duration(minutes: 59, seconds: 59)),
        '00:59:59');
    expect(formatCountdown(Duration.zero), '00:00:00');
  });

  testWidgets('hides the mirage section when it is empty', (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson()));

    await pumpStockScreen(tester, api);

    expect(find.text('Normal Dealer'), findsOneWidget);
    expect(find.text('Mirage Dealer'), findsNothing);
  });

  testWidgets('shows a sensible empty state when no stock is recorded',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson(
      normalFruits: const [],
      mirageFruits: const [],
    )));

    await pumpStockScreen(tester, api);

    expect(find.text('No stock recorded yet'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the request fails',
      (tester) async {
    final api = _apiWith(MockClient((request) async {
      return http.Response('boom', 500);
    }));

    await pumpStockScreen(tester, api);

    expect(find.text('Could not load the stock'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Retry after the server recovers shows the stock again.
    final api2 = _apiWith(_mockStockResponse(_stockJson()));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: StockScreen(stockApi: api2)));
    await pumpFrames(tester);
    expect(find.text('Flame'), findsOneWidget);
  });

  testWidgets('shows an error state when the server is unreachable',
      (tester) async {
    final api = _apiWith(MockClient((request) async {
      throw http.ClientException('connection refused');
    }));

    await pumpStockScreen(tester, api);

    expect(find.text('Could not load the stock'), findsOneWidget);
  });

  testWidgets('shows an update banner when a newer release exists',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson()));
    final updateService = UpdateService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.1',
            'body': 'notes',
            'assets': [
              {
                'name': 'blox-notify-1.0.1+2.apk',
                'browser_download_url':
                    'https://example.com/blox-notify-1.0.1+2.apk',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: StockScreen(
        stockApi: api,
        updateService: updateService,
        versionProvider: () async => 1,
      ),
    ));
    await pumpFrames(tester);

    expect(find.textContaining('Update available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows no update banner when the app is up to date',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_stockJson()));
    final updateService = UpdateService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0',
            'assets': [
              {
                'name': 'blox-notify-1.0.0+1.apk',
                'browser_download_url':
                    'https://example.com/blox-notify-1.0.0+1.apk',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: StockScreen(
        stockApi: api,
        updateService: updateService,
        versionProvider: () async => 1,
      ),
    ));
    await pumpFrames(tester);

    expect(find.textContaining('Update available'), findsNothing);
  });
}
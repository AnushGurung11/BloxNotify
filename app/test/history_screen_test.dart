import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/screens/history_screen.dart';
import 'package:blox_notify/services/stock_api.dart';

StockApi _apiWith(MockClient client) => StockApi(
      client: client,
      baseUrl: 'http://test.local',
    );

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Uses a tall test surface so the whole history layout (header, leaderboard
/// and day-grouped restocks) fits without scrolling.
Future<void> pumpHistory(WidgetTester tester, StockApi api) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: HistoryScreen(stockApi: api)));
  await pumpFrames(tester);
}

// 40 hours apart so the two events can never fall on the same local day in
// any timezone.
final _t1 = DateTime.utc(2026, 8, 19, 7, 0, 2).millisecondsSinceEpoch ~/ 1000;
final _t2 = DateTime.utc(2026, 8, 19, 6, 30, 2).millisecondsSinceEpoch ~/ 1000;
final _t3 = _t1 - 40 * 3600;

final _events = [
  {
    'type': 'Mirage',
    'timestamp': _t1,
    'time': DateTime.fromMillisecondsSinceEpoch(_t1 * 1000, isUtc: true)
        .toIso8601String(),
    'items': [
      {
        'name': 'Dough',
        'imageUrl': 'https://cdn.example/dough.webp',
        'price': 3500000,
      },
      {'name': 'Rocket', 'price': 0},
    ],
  },
  {
    'type': 'Normal',
    'timestamp': _t2,
    'time': DateTime.fromMillisecondsSinceEpoch(_t2 * 1000, isUtc: true)
        .toIso8601String(),
    'items': [
      {'name': 'Dough', 'price': 2500000},
    ],
  },
  {
    'type': 'Normal',
    'timestamp': _t3,
    'time': DateTime.fromMillisecondsSinceEpoch(_t3 * 1000, isUtc: true)
        .toIso8601String(),
    'items': [
      {'name': 'Ice', 'price': 125000},
    ],
  },
];

MockClient mockHistory({bool ready = true}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/stock/history')) {
      return http.Response(
        jsonEncode({
          'ready': ready,
          'source': 'bloxvalues',
          'updatedAt': _t1 * 1000,
          'events': ready ? _events : [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 200);
  });
}

DateTime _eventTime(int timestamp) =>
    DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

void main() {
  testWidgets('renders day-grouped restocks with dealer badges and chips',
      (tester) async {
    final api = _apiWith(mockHistory());
    await pumpHistory(tester, api);

    // Header with the last-updated moment and the data source.
    expect(
      find.text('Updated ${formatHistoryDay(_eventTime(_t1))} · bloxvalues.net'),
      findsOneWidget,
    );

    // Dealer badges and event times (12-hour, local).
    expect(find.text('NORMAL DEALER'), findsNWidgets(2));
    expect(find.text('MIRAGE DEALER'), findsOneWidget);
    expect(find.text(formatHistoryTime(_eventTime(_t1))), findsOneWidget);

    // Day labels: the two first events share a local day, the third is 40h
    // earlier, so there are exactly two distinct day groups.
    expect(find.text(formatHistoryDay(_eventTime(_t3)).toUpperCase()), findsOneWidget);
    expect(find.text(formatHistoryDay(_eventTime(_t1)).toUpperCase()), findsOneWidget);

    // Fruit chips with prices (Dough appears in two events).
    expect(find.text('Dough'), findsNWidgets(3)); // 2 chips + leaderboard
    expect(find.text('\$3,500,000'), findsOneWidget);
    expect(find.text('\$2,500,000'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Ice'), findsNWidgets(2)); // chip + leaderboard

    // Leaderboard ranks Dough first (appeared twice).
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);

    // Chips use the source's image URLs where provided.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image.toString().contains('cdn.example/dough.webp'),
      ),
      findsWidgets,
    );
  });

  testWidgets('shows an empty state when there is no history', (tester) async {
    final api = _apiWith(mockHistory(ready: false));

    await pumpHistory(tester, api);

    expect(find.text('No history yet'), findsOneWidget);
  });

  testWidgets('shows an error state when the request fails', (tester) async {
    final api = _apiWith(MockClient((request) async {
      throw http.ClientException('connection refused');
    }));

    await pumpHistory(tester, api);

    expect(find.text('Could not load the history'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
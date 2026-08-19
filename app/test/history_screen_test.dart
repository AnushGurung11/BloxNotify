import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/screens/history_screen.dart';
import 'package:blox_notify/screens/stock_screen.dart' show formatStockTimestamp;
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

void main() {
  Future<void> pumpHistory(WidgetTester tester, StockApi api) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(stockApi: api)));
    await pumpFrames(tester);
  }

  MockClient mockHistory(List<Map<String, dynamic>> history) {
    return MockClient((request) async {
      return http.Response(
        jsonEncode({
          'normal': {
            'fruits': [
              {'name': 'Spring', 'imageUrl': null},
            ],
            'updatedAt': '2026-08-18T12:00:00.000Z',
          },
          'mirage': {
            'fruits': [],
            'updatedAt': '2026-08-18T12:00:00.000Z',
          },
          'history': history,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  testWidgets('renders history entries with normal and mirage stock',
      (tester) async {
    final api = _apiWith(mockHistory([
      {
        'fruits': ['Ice', 'Venom'],
        'mirageFruits': ['Dough'],
        'updatedAt': '2026-08-18T12:30:00.000Z',
      },
      {
        'fruits': ['Portal'],
        'mirageFruits': [],
        'updatedAt': '2026-08-18T08:00:00.000Z',
      },
    ]));

    await pumpHistory(tester, api);

    expect(find.text('Ice, Venom'), findsOneWidget);
    expect(find.text('Mirage: Dough'), findsOneWidget);
    expect(find.text('Portal'), findsOneWidget);
    // Times render through formatStockTimestamp (12-hour clock, local time).
    expect(
      find.text(formatStockTimestamp(DateTime.parse('2026-08-18T12:30:00.000Z'))),
      findsOneWidget,
    );
    expect(find.text('Stock History'), findsOneWidget); // AppBar title
  });

  testWidgets('shows an empty state when there is no history', (tester) async {
    final api = _apiWith(mockHistory([]));

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
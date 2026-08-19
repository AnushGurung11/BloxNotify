import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/screens/values_screen.dart';
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

MockClient mockValues(List<Map<String, dynamic>> items) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/values')) {
      return http.Response(
        jsonEncode({'ready': true, 'updatedAt': 1787054400000, 'items': items}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 200);
  });
}

const _values = [
  {
    'id': 1,
    'name': 'Dragon',
    'normalValue': 120000000,
    'permanentValue': 4500,
    'demand': 'Very High',
    'trend': 'Stable',
    'category': 'Fruits',
    'rarity': 'Mythical',
    'fruitType': 'Beast',
    'imageUrl': null,
  },
  {
    'id': 2,
    'name': 'Rocket',
    'normalValue': 1000,
    'permanentValue': null,
    'demand': 'Low',
    'trend': 'Falling',
    'category': 'Fruits',
    'rarity': 'Common',
    'fruitType': 'Elemental',
    'imageUrl': null,
  },
  {
    'id': 3,
    'name': '2x Money',
    'normalValue': 5000000,
    'permanentValue': 450,
    'demand': 'High',
    'trend': 'Stable',
    'category': 'Gamepasses',
    'rarity': 'Gamepass',
    'fruitType': null,
    'imageUrl': null,
  },
];

void main() {
  Future<void> pumpValues(WidgetTester tester, StockApi api) async {
    await tester.pumpWidget(MaterialApp(home: ValuesScreen(stockApi: api)));
    await pumpFrames(tester);
  }

  testWidgets('renders items with values, demand, trend and rarity',
      (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpValues(tester, api);

    expect(find.text('Dragon'), findsOneWidget);
    expect(find.text('120M in-game · 4.5K Robux'), findsOneWidget);
    expect(find.text('Mythical'), findsOneWidget);
    expect(find.text('Very High'), findsOneWidget);
    expect(find.text('Rocket'), findsOneWidget);
    expect(find.text('1K in-game'), findsOneWidget);
    expect(find.text('2x Money'), findsOneWidget);
    expect(find.text('5M in-game · 450 Robux'), findsOneWidget);
    expect(find.text('Gamepasses'), findsOneWidget); // category filter chip
    expect(find.byIcon(Icons.trending_down), findsOneWidget); // Falling
  });

  testWidgets('filters items by search query', (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpValues(tester, api);

    await tester.enterText(find.byType(TextField), 'rock');
    await tester.pump();

    expect(find.text('Rocket'), findsOneWidget);
    expect(find.text('Dragon'), findsNothing);
    expect(find.text('2x Money'), findsNothing);
  });

  testWidgets('filters items by category chip', (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpValues(tester, api);

    await tester.tap(find.text('Gamepasses'));
    await tester.pump();

    expect(find.text('2x Money'), findsOneWidget);
    expect(find.text('Dragon'), findsNothing);
    expect(find.text('Rocket'), findsNothing);
  });

  testWidgets('shows a retry state when values are unavailable',
      (tester) async {
    final api = _apiWith(MockClient((request) async {
      return http.Response(
        jsonEncode({'ready': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));
    await pumpValues(tester, api);

    expect(find.text('No values yet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
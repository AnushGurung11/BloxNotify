import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/models/value.dart';
import 'package:blox_notify/screens/trade_screen.dart';
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
    'name': 'Dough',
    'normalValue': 55000000,
    'permanentValue': 2450,
    'demand': 'Very High',
    'trend': 'Stable',
    'category': 'Fruits',
    'rarity': 'Mythical',
    'imageUrl': null,
  },
  {
    'id': 2,
    'name': 'Venom',
    'normalValue': 10000000,
    'permanentValue': null,
    'demand': 'High',
    'trend': 'Increasing',
    'category': 'Fruits',
    'rarity': 'Legendary',
    'imageUrl': null,
  },
  {
    'id': 3,
    'name': 'Dragon',
    'normalValue': 120000000,
    'permanentValue': 4500,
    'demand': 'Very High',
    'trend': 'Stable',
    'category': 'Fruits',
    'rarity': 'Mythical',
    'imageUrl': null,
  },
];

Future<void> _selectAndAdd(
  WidgetTester tester, {
  required bool firstSide,
  required String itemLabel,
}) async {
  final dropdowns = find.byType(DropdownButtonFormField<ValueItem>);
  await tester.tap(dropdowns.at(firstSide ? 0 : 1));
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemLabel).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.add).at(firstSide ? 0 : 1));
  await tester.pump();
}

void main() {
  testWidgets('shows a loss bar when giving more than receiving',
      (tester) async {
    final api = _apiWith(mockValues(_values));
    await tester.pumpWidget(MaterialApp(home: TradeScreen(stockApi: api)));
    await pumpFrames(tester);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await _selectAndAdd(tester, firstSide: false, itemLabel: 'Venom (10M)');

    expect(find.text('You give'), findsOneWidget);
    expect(find.text('You receive'), findsOneWidget);
    expect(find.text('Dough (55M)'), findsOneWidget);
    expect(find.text('Venom (10M)'), findsOneWidget);
    // Totals appear in the side card header and in the comparison row.
    expect(find.text('55M'), findsNWidgets(2)); // given total
    expect(find.text('10M'), findsNWidgets(2)); // received total
    expect(find.text('Loss'), findsOneWidget);
    expect(find.text('You lose 45M in value'), findsOneWidget);
  });

  testWidgets('flips to a win bar when receiving more value', (tester) async {
    final api = _apiWith(mockValues(_values));
    await tester.pumpWidget(MaterialApp(home: TradeScreen(stockApi: api)));
    await pumpFrames(tester);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await _selectAndAdd(tester, firstSide: false, itemLabel: 'Dragon (120M)');

    expect(find.text('Win'), findsOneWidget);
    expect(find.text('You gain 65M in value'), findsOneWidget);
  });

  testWidgets('removes an item and clears both sides', (tester) async {
    final api = _apiWith(mockValues(_values));
    await tester.pumpWidget(MaterialApp(home: TradeScreen(stockApi: api)));
    await pumpFrames(tester);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    expect(find.text('Dough (55M)'), findsOneWidget);

    // Remove the chip via its delete icon.
    await tester.tap(find.descendant(
      of: find.byType(InputChip),
      matching: find.byIcon(Icons.close),
    ));
    await tester.pump();
    expect(find.text('Dough (55M)'), findsNothing);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Dough (55M)'), findsNothing);
    expect(find.text('Add items to both sides to compare values'), findsOneWidget);
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
    await tester.pumpWidget(MaterialApp(home: TradeScreen(stockApi: api)));
    await pumpFrames(tester);

    expect(find.text('Trade calculator unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
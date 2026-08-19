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

/// Uses a tall test surface so the whole trade layout (two side cards plus
/// the verdict row) fits without scrolling.
Future<void> pumpTrade(WidgetTester tester, StockApi api) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: TradeScreen(stockApi: api)));
  await pumpFrames(tester);
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
  testWidgets('shows a loss when giving more than receiving',
      (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpTrade(tester, api);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await _selectAndAdd(tester, firstSide: false, itemLabel: 'Venom (10M)');

    expect(find.text('You give'), findsOneWidget);
    expect(find.text('You receive'), findsOneWidget);
    // Selected items appear as image tiles (name + value in the tile).
    expect(find.text('Dough'), findsOneWidget);
    expect(find.text('Venom'), findsOneWidget);
    // Each total shows in the side header, the comparison row and the tile.
    expect(find.text('55M'), findsNWidgets(3)); // given total
    expect(find.text('10M'), findsNWidgets(3)); // received total
    expect(find.text('Loss'), findsOneWidget);
    expect(find.text('You lose 45M in value'), findsOneWidget);
    // No progress bar — just the win/loss verdict and amount.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('flips to a win when receiving more value', (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpTrade(tester, api);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await _selectAndAdd(tester, firstSide: false, itemLabel: 'Dragon (120M)');

    expect(find.text('Win'), findsOneWidget);
    expect(find.text('You gain 65M in value'), findsOneWidget);
  });

  testWidgets('removes an item from the grid and clears both sides',
      (tester) async {
    final api = _apiWith(mockValues(_values));
    await pumpTrade(tester, api);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    expect(find.text('Dough'), findsOneWidget);

    // Remove the tile via its close badge.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Dough'), findsNothing);

    await _selectAndAdd(tester, firstSide: true, itemLabel: 'Dough (55M)');
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Dough'), findsNothing);
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
    await pumpTrade(tester, api);

    expect(find.text('Trade calculator unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

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

MockClient _mockStockResponse(List<Map<String, dynamic>> fruits,
    {String? updatedAt}) {
  return MockClient((request) async {
    return http.Response(
      jsonEncode({'fruits': fruits, 'updatedAt': updatedAt}),
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

void main() {
  Future<void> pumpStockScreen(WidgetTester tester, StockApi api) async {
    await tester.pumpWidget(MaterialApp(home: StockScreen(stockApi: api)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a fruit card per fruit with names and images',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_fruits));

    await pumpStockScreen(tester, api);

    expect(find.text('Spring'), findsOneWidget);
    expect(find.text('Flame'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows the last-updated timestamp', (tester) async {
    final api = _apiWith(
      _mockStockResponse(_fruits, updatedAt: '2026-08-18T12:00:00.000Z'),
    );

    await pumpStockScreen(tester, api);

    expect(find.textContaining('Last updated:'), findsOneWidget);
  });

  testWidgets('shows a sensible empty state when no stock is recorded',
      (tester) async {
    final api = _apiWith(_mockStockResponse([]));

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
    final api2 = _apiWith(_mockStockResponse(_fruits));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: StockScreen(stockApi: api2)));
    await tester.pumpAndSettle();
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
    final api = _apiWith(_mockStockResponse(_fruits));
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
    await tester.pumpAndSettle();

    expect(find.textContaining('Update available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows no update banner when the app is up to date',
      (tester) async {
    final api = _apiWith(_mockStockResponse(_fruits));
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
    await tester.pumpAndSettle();

    expect(find.textContaining('Update available'), findsNothing);
  });
}
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blox_notify/screens/predictions_screen.dart';
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
  Future<void> pumpPredictions(WidgetTester tester, StockApi api) async {
    await tester.pumpWidget(
        MaterialApp(home: PredictionsScreen(stockApi: api)));
    await pumpFrames(tester);
  }

  MockClient mockPredictions(Map<String, dynamic>? predictions) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/stock/predictions')) {
        return http.Response(
          jsonEncode(predictions ?? {'ready': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200);
    });
  }

  testWidgets('renders prediction cards with images, rarity, confidence and rating',
      (tester) async {
    final api = _apiWith(mockPredictions({
      'ready': true,
      'nextResetAt': DateTime.now().toUtc().millisecondsSinceEpoch +
          2 * 3600 * 1000,
      'predictions': [
        {
          'name': 'Dough',
          'confidence': 0.31,
          'imageUrl': 'http://test.local/dough.png',
          'rarity': 'Mythical',
        },
        {'name': 'Venom', 'confidence': 0.22, 'imageUrl': null, 'rarity': null},
      ],
      'rating': {
        'top1Accuracy': 32.3,
        'top3Accuracy': 63.2,
        'testedRotations': 10972,
      },
    }));

    await pumpPredictions(tester, api);

    expect(find.text('#1 Dough'), findsOneWidget);
    expect(find.text('#2 Venom'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Mythical'), findsOneWidget); // rarity badge
    expect(find.textContaining('31% confidence'), findsOneWidget);
    expect(find.textContaining('Model rating: 63.2%'), findsOneWidget);
    expect(find.textContaining('10972 rotations backtested'), findsOneWidget);
    expect(find.textContaining('Based on 10.9k'), findsOneWidget);
    expect(find.textContaining('in 0'), findsOneWidget); // countdown present
  });

  testWidgets('does not show a Best Times section anymore', (tester) async {
    final api = _apiWith(mockPredictions({
      'ready': true,
      'nextResetAt': DateTime.now().toUtc().millisecondsSinceEpoch +
          2 * 3600 * 1000,
      'predictions': [
        {'name': 'Dough', 'confidence': 0.31, 'imageUrl': null},
      ],
      'rating': {
        'top1Accuracy': 32.3,
        'top3Accuracy': 63.2,
        'testedRotations': 10972,
      },
    }));

    await pumpPredictions(tester, api);

    expect(find.text('Best Times to Check'), findsNothing);
    expect(find.textContaining('20:00 UTC'), findsNothing);
  });

  testWidgets('shows a friendly empty state when the backend has no model',
      (tester) async {
    final api = _apiWith(mockPredictions({'ready': false}));

    await pumpPredictions(tester, api);

    expect(find.text('No predictions yet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows a friendly empty state when the request fails',
      (tester) async {
    final api = _apiWith(MockClient((request) async {
      throw http.ClientException('connection refused');
    }));

    await pumpPredictions(tester, api);

    expect(find.text('No predictions yet'), findsOneWidget);
  });
}
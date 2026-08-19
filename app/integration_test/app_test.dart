import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:blox_notify/main.dart';

import '../test/fake_push_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Bounded pumping: the stock screen's countdown timer ticks forever, so
  // pumpAndSettle would never settle.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('launch -> permission request -> topic subscription -> stock grid',
      (tester) async {
    final push = FakePushService();

    await tester.pumpWidget(BloxNotifyApp(pushService: push));
    await pumpFrames(tester);

    expect(find.text('Enable notifications'), findsOneWidget);

    await tester.tap(find.text('Enable notifications'));
    await pumpFrames(tester);

    expect(push.permissionRequested, isTrue);
    expect(push.subscribedTopics, contains('stock_updates'));

    expect(find.text('Current Stock'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget); // bottom tab bar
    expect(find.text('Trade'), findsOneWidget);
    expect(find.text('Values'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
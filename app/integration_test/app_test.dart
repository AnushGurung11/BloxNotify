import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:blox_notify/main.dart';

import '../test/fake_push_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch -> permission request -> topic subscription -> stock grid',
      (tester) async {
    final push = FakePushService();

    await tester.pumpWidget(BloxNotifyApp(pushService: push));
    await tester.pumpAndSettle();

    expect(find.text('Enable notifications'), findsOneWidget);

    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(push.permissionRequested, isTrue);
    expect(push.subscribedTopics, contains('stock_updates'));

    expect(find.text('Current Stock'), findsOneWidget);
  });
}
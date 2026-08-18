import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blox_notify/screens/onboarding_screen.dart';

import 'fake_push_service.dart';

void main() {
  testWidgets('requesting permission subscribes to the stock topic',
      (tester) async {
    final push = FakePushService();
    var done = false;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        pushService: push,
        onDone: () => done = true,
      ),
    ));

    expect(find.text('Enable notifications'), findsOneWidget);
    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(push.permissionRequested, isTrue);
    expect(push.subscribedTopics, ['stock_updates']);
    expect(done, isTrue);
  });

  testWidgets('skipping does not request permission', (tester) async {
    final push = FakePushService();
    var done = false;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        pushService: push,
        onDone: () => done = true,
      ),
    ));

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();

    expect(push.permissionRequested, isFalse);
    expect(push.subscribedTopics, isEmpty);
    expect(done, isTrue);
  });
}
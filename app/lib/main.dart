import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'screens/stock_screen.dart';
import 'services/fcm_service.dart';
import 'services/stock_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // google-services.json is a manual setup step — without it the app still
    // works, only push notifications are unavailable.
    debugPrint('Firebase init failed (is google-services.json present?): $e');
  }
  runApp(const BloxNotifyApp());
}

class BloxNotifyApp extends StatefulWidget {
  const BloxNotifyApp({super.key, this.pushService, this.stockApi});

  /// Injectable for tests; defaults to the real FCM-backed service.
  final PushService? pushService;

  /// Injectable for tests; defaults to the real backend client.
  final StockApi? stockApi;

  @override
  State<BloxNotifyApp> createState() => _BloxNotifyAppState();
}

class _BloxNotifyAppState extends State<BloxNotifyApp> {
  late final PushService _pushService;
  late final StockApi _stockApi;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _pushService = widget.pushService ?? FcmService();
    _stockApi = widget.stockApi ?? StockApi();
    _pushService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blox Notify',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: _onboarded
          ? StockScreen(stockApi: _stockApi)
          : OnboardingScreen(
              pushService: _pushService,
              onDone: () => setState(() => _onboarded = true),
            ),
    );
  }
}
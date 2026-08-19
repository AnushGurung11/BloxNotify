import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/predictions_screen.dart';
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
  static const _onboardedKey = 'onboarded';

  late final PushService _pushService;
  late final StockApi _stockApi;

  /// null while the persisted flag is being read.
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _pushService = widget.pushService ?? FcmService();
    _stockApi = widget.stockApi ?? StockApi();
    _pushService.init();
    _loadOnboardedFlag();
  }

  Future<void> _loadOnboardedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _onboarded = prefs.getBool(_onboardedKey) ?? false);
  }

  /// Marks onboarding as done so it shows only once, ever.
  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
    if (!mounted) return;
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = _onboarded;
    return MaterialApp(
      title: 'Blox Notify',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: onboarded == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : onboarded
              ? HomeShell(stockApi: _stockApi)
              : OnboardingScreen(
                  pushService: _pushService,
                  onDone: _finishOnboarding,
                ),
    );
  }
}

/// Bottom-tab shell hosting the Stock, Predictions and History screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          StockScreen(stockApi: widget.stockApi),
          PredictionsScreen(stockApi: widget.stockApi),
          HistoryScreen(stockApi: widget.stockApi),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Predictions',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
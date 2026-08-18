/// Central app configuration — change the API URL here (or via
/// `--dart-define=API_BASE_URL=...` at build time) before shipping a release.
class AppConfig {
  AppConfig._();

  /// Base URL of the Blox Notify backend.
  ///
  /// Defaults to 10.0.2.2 (the host machine as seen from the Android
  /// emulator). For a physical device, use your machine's LAN IP, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// FCM topic the device subscribes to.
  static const String fcmTopic = 'stock_updates';
}
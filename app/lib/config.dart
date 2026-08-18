/// Central app configuration — change the API URL here (or via
/// `--dart-define=API_BASE_URL=...` at build time) before shipping a release.
class AppConfig {
  AppConfig._();

  /// Base URL of the Blox Notify backend.
  ///
  /// Override at build time for a different backend:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` (local dev
  /// via Android emulator), or your own deployed instance.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bloxnotify.onrender.com',
  );

  /// FCM topic the device subscribes to.
  static const String fcmTopic = 'stock_updates';
}
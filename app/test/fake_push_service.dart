import 'package:blox_notify/services/fcm_service.dart';

/// In-memory PushService for widget and integration tests — records calls
/// instead of talking to Firebase.
class FakePushService implements PushService {
  bool initCalled = false;
  bool permissionRequested = false;
  bool permissionGranted = true;
  final List<String> subscribedTopics = [];

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return permissionGranted;
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    subscribedTopics.add(topic);
  }
}
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/fcm_service.dart';

/// First-launch screen: asks for notification permission and subscribes the
/// device to the stock topic before moving on to the stock screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.pushService,
    required this.onDone,
  });

  final PushService pushService;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;

  Future<void> _enableNotifications() async {
    setState(() => _busy = true);
    try {
      final granted = await widget.pushService.requestPermission();
      if (granted) {
        await widget.pushService.subscribeToTopic(AppConfig.fcmTopic);
      }
    } catch (_) {
      // never leave the user stuck — proceed to the stock screen either way
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.notifications_active_outlined,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text('Blox Notify', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Get notified the moment the Blox Fruits shop stock changes, '
                'with the new fruits right in the notification.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _enableNotifications,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enable notifications'),
                ),
              ),
              TextButton(
                onPressed: widget.onDone,
                child: const Text('Maybe later'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
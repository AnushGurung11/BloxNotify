import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/fruit.dart';
import '../services/stock_api.dart';
import '../services/update_service.dart';

/// Formats a timestamp as `2026-08-18 08:15 PM` (12-hour clock, local time).
String formatStockTimestamp(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  final mm = local.minute.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$mm $ampm';
}

/// Formats a duration as `HH:MM:SS`.
String formatCountdown(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Shows the current stock for both dealers with countdowns to the next
/// rotation.
class StockScreen extends StatefulWidget {
  const StockScreen({
    super.key,
    required this.stockApi,
    this.updateService,
    this.versionProvider,
  });

  final StockApi stockApi;

  /// Injectable for tests; defaults to the real GitHub Releases check.
  final UpdateService? updateService;

  /// Injectable for tests; defaults to the installed app's versionCode via
  /// package_info_plus.
  final Future<int?> Function()? versionProvider;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late Future<StockSnapshot> _future;
  late final UpdateService _updateService;
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    _future = widget.stockApi.fetchCurrentStock();
    _updateService = widget.updateService ?? UpdateService();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    try {
      final installedVersion = await (widget.versionProvider ??
          () async {
            final info = await PackageInfo.fromPlatform();
            return int.tryParse(info.buildNumber);
          })();
      if (installedVersion == null) return;

      final update = await _updateService.checkForUpdate(installedVersion);
      if (update != null && mounted) {
        _showUpdateBanner(update);
      }
    } catch (_) {
      // version lookup or update check failed — skip silently
    }
  }

  void _showUpdateBanner(AppUpdate update) {
    ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
      content: Text('Update available: v${update.versionName}'),
      leading: const Icon(Icons.system_update_alt),
      actions: [
        TextButton(
          onPressed: () => launchUrl(Uri.parse(update.downloadUrl),
              mode: LaunchMode.externalApplication),
          child: const Text('Download'),
        ),
        TextButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Dismiss'),
        ),
      ],
    ));
  }

  Future<void> _refresh() async {
    final future = widget.stockApi.fetchCurrentStock();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // errors surface through the FutureBuilder
    }
  }

  void _reload() {
    setState(() => _future = widget.stockApi.fetchCurrentStock());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Stock')),
      body: FutureBuilder<StockSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: '${snapshot.error}', onRetry: _reload);
          }
          final stock = snapshot.data!;
          if (stock.isEmpty) {
            return _EmptyView(onRetry: _reload);
          }
          return _StockView(stock: stock, onRefresh: _refresh);
        },
      ),
    );
  }
}

class _StockView extends StatelessWidget {
  const _StockView({required this.stock, required this.onRefresh});

  final StockSnapshot stock;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            stock.normal.updatedAt == null
                ? 'Never updated'
                : 'Last updated: ${formatStockTimestamp(stock.normal.updatedAt!)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _DealerSection(
            title: 'Normal Dealer',
            dealer: stock.normal,
            icon: Icons.storefront,
          ),
          if (stock.mirage.fruits.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DealerSection(
              title: 'Mirage Dealer',
              dealer: stock.mirage,
              icon: Icons.auto_awesome,
            ),
          ],
        ],
      ),
    );
  }
}

class _DealerSection extends StatelessWidget {
  const _DealerSection({
    required this.title,
    required this.dealer,
    required this.icon,
  });

  final String title;
  final DealerStock dealer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 2),
        if (dealer.nextResetAt != null)
          _CountdownText(nextResetAt: dealer.nextResetAt!),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final fruit in dealer.fruits) _FruitTile(fruit: fruit),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ticks every second, showing the time until the next stock rotation.
class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.nextResetAt});

  final DateTime nextResetAt;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final diff = widget.nextResetAt.difference(now);
    final remaining = diff.isNegative ? Duration.zero : diff;
    return Text(
      'Next rotation in ${formatCountdown(remaining)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _FruitTile extends StatelessWidget {
  const _FruitTile({required this.fruit});

  final Fruit fruit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: fruit.imageUrl != null
                  ? Image.network(
                      fruit.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _NoImage(),
                    )
                  : const _NoImage(),
            ),
          ),
          const SizedBox(height: 6),
          Text(fruit.name, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, size: 32),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('Could not load the stock'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('No stock recorded yet'),
            const SizedBox(height: 8),
            const Text(
              'The backend has not captured a stock rotation yet. '
              'Pull to refresh or try again later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
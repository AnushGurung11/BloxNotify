import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/fruit.dart';
import '../models/prediction.dart';
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

/// Shows the current stock as a compact single row plus the stock history.
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
  late Future<PredictionResult?> _predictionsFuture;
  late final UpdateService _updateService;
  bool _updateChecked = false;

  /// Fetches predictions; failures are swallowed — the section simply hides.
  Future<PredictionResult?> _fetchPredictionsSafely() =>
      widget.stockApi.fetchPredictions().catchError((_) => null);

  @override
  void initState() {
    super.initState();
    _future = widget.stockApi.fetchCurrentStock();
    _predictionsFuture = _fetchPredictionsSafely();
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
    final predictionsFuture = _fetchPredictionsSafely();
    setState(() {
      _future = future;
      _predictionsFuture = predictionsFuture;
    });
    try {
      await future;
    } catch (_) {
      // errors surface through the FutureBuilder
    }
  }

  void _reload() {
    setState(() {
      _future = widget.stockApi.fetchCurrentStock();
      _predictionsFuture = _fetchPredictionsSafely();
    });
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
          return _StockView(
            stock: stock,
            onRefresh: _refresh,
            predictions: _predictionsFuture,
          );
        },
      ),
    );
  }
}

class _StockView extends StatelessWidget {
  const _StockView({
    required this.stock,
    required this.onRefresh,
    required this.predictions,
  });

  final StockSnapshot stock;
  final Future<void> Function() onRefresh;
  final Future<PredictionResult?> predictions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatedAt = stock.updatedAt;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            updatedAt == null
                ? 'Never updated'
                : 'Last updated: ${formatStockTimestamp(updatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final fruit in stock.fruits) _FruitTile(fruit: fruit),
              ],
            ),
          ),
          FutureBuilder<PredictionResult?>(
            future: predictions,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final result = snapshot.data;
              if (result == null || result.predictions.isEmpty) {
                return const SizedBox.shrink();
              }
              return _PredictionsSection(result: result);
            },
          ),
          if (stock.history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Stock History', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in stock.history) _HistoryTile(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _PredictionsSection extends StatelessWidget {
  const _PredictionsSection({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = result.rating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Predicted Next Stock', style: theme.textTheme.titleMedium),
        if (result.nextResetAt != null) ...[
          const SizedBox(height: 2),
          Text(
            'Next rotation: ${formatStockTimestamp(result.nextResetAt!)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Based on ${_rotationsLabel(rating)} of wiki stock history',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, p) in result.predictions.indexed)
              _PredictionChip(rank: i + 1, prediction: p),
          ],
        ),
        if (rating != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Model rating: ${rating.top3Accuracy.toStringAsFixed(1)}% '
                  'top-3 accuracy '
                  '(${rating.top1Accuracy.toStringAsFixed(1)}% top-1, '
                  '${rating.testedRotations} rotations backtested)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _rotationsLabel(PredictionRating? rating) {
    if (rating == null || rating.testedRotations == 0) return '';
    final n = rating.testedRotations;
    if (n < 1000) return '$n';
    return '${((n / 1000) * 10).floor() / 10}k';
  }
}

class _PredictionChip extends StatelessWidget {
  const _PredictionChip({required this.rank, required this.prediction});

  final int rank;
  final FruitPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = (prediction.confidence * 100).clamp(0, 100);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#$rank ${prediction.name}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: confidence / 100,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${confidence.toStringAsFixed(0)}% confidence',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final StockHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = entry.updatedAt == null
        ? 'Unknown time'
        : formatStockTimestamp(entry.updatedAt!);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.history, color: theme.colorScheme.primary),
        title: Text(entry.fruits.join(', ')),
        subtitle: Text(when),
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
